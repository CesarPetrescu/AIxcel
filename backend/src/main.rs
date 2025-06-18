use actix_web::{web, App, HttpResponse, HttpServer, Responder, HttpRequest};
use actix_web_actors::ws;
use actix::{Actor, StreamHandler, Addr, Message, AsyncContext};
use actix_cors::Cors;
use rusqlite::{params, Connection};
use serde::{Deserialize, Serialize};
use std::sync::{Mutex, Arc};
use std::collections::HashMap;
use evalexpr::*;
use regex;
use uuid::Uuid;

pub struct AppState {
    pub db: Mutex<Connection>,
    pub sessions: Arc<Mutex<HashMap<String, Addr<WebSocketSession>>>>,
}

#[derive(Serialize, Deserialize, Debug, Clone)]
struct Cell {
    row: i32,
    col: i32,
    value: String,
    font_weight: Option<String>,
    font_style: Option<String>,
    background_color: Option<String>,
}

// WebSocket message types
#[derive(Message, Serialize, Deserialize, Clone)]
#[rtype(result = "()")]
pub struct CellUpdate {
    pub row: i32,
    pub col: i32,
    pub value: String,
    pub font_weight: Option<String>,
    pub font_style: Option<String>,
    pub background_color: Option<String>,
    pub user_id: String,
}

#[derive(Message, Serialize, Deserialize, Clone)]
#[rtype(result = "()")]
pub struct UserJoined {
    pub user_id: String,
}

#[derive(Message, Serialize, Deserialize, Clone)]
#[rtype(result = "()")]
pub struct UserLeft {
    pub user_id: String,
}

// WebSocket session actor
pub struct WebSocketSession {
    pub id: String,
    pub sessions: Arc<Mutex<HashMap<String, Addr<WebSocketSession>>>>,
}

impl Actor for WebSocketSession {
    type Context = ws::WebsocketContext<Self>;

    fn started(&mut self, ctx: &mut Self::Context) {
        let mut sessions = self.sessions.lock().unwrap();
        sessions.insert(self.id.clone(), ctx.address());
        
        // Notify other users that a new user joined
        let msg = UserJoined { user_id: self.id.clone() };
        let msg_str = serde_json::to_string(&msg).unwrap();
        
        for (session_id, addr) in sessions.iter() {
            if session_id != &self.id {
                addr.do_send(WebSocketMessage(msg_str.clone()));
            }
        }
    }

    fn stopped(&mut self, _ctx: &mut Self::Context) {
        let mut sessions = self.sessions.lock().unwrap();
        sessions.remove(&self.id);
        
        // Notify other users that user left
        let msg = UserLeft { user_id: self.id.clone() };
        let msg_str = serde_json::to_string(&msg).unwrap();
        
        for (_, addr) in sessions.iter() {
            addr.do_send(WebSocketMessage(msg_str.clone()));
        }
    }
}

#[derive(Message)]
#[rtype(result = "()")]
pub struct WebSocketMessage(pub String);

impl StreamHandler<Result<ws::Message, ws::ProtocolError>> for WebSocketSession {
    fn handle(&mut self, msg: Result<ws::Message, ws::ProtocolError>, ctx: &mut Self::Context) {
        match msg {
            Ok(ws::Message::Ping(msg)) => ctx.pong(&msg),
            Ok(ws::Message::Text(text)) => {
                // Handle incoming cell updates
                if let Ok(cell_update) = serde_json::from_str::<CellUpdate>(&text) {
                    // Broadcast to all other sessions
                    let sessions = self.sessions.lock().unwrap();
                    for (session_id, addr) in sessions.iter() {
                        if session_id != &self.id {
                            addr.do_send(WebSocketMessage(text.to_string()));
                        }
                    }
                }
            },
            Ok(ws::Message::Binary(_)) => {},
            _ => {}
        }
    }
}

impl actix::Handler<WebSocketMessage> for WebSocketSession {
    type Result = ();

    fn handle(&mut self, msg: WebSocketMessage, ctx: &mut Self::Context) {
        ctx.text(msg.0);
    }
}

fn eval_formula(expr: &str, db_conn: &Connection) -> Result<String, String> {
    let expr = expr.trim_start_matches('=');
    let mut ctx = HashMapContext::new();
    ctx.set_function(
        "SUM".to_string(),
        Function::new(|arg| -> EvalexprResult<Value> {
            let args = arg.as_tuple()?;
            let mut sum = 0.0;
            for v in args.iter() {
                sum += v.as_number()?;
            }
            Ok(Value::from_float(sum))
        }),
    )
    .unwrap();
    ctx.set_function(
        "AVERAGE".to_string(),
        Function::new(|arg| -> EvalexprResult<Value> {
            let args = arg.as_tuple()?;
            let mut sum = 0.0;
            for v in args.iter() {
                sum += v.as_number()?;
            }
            let avg = sum / args.len() as f64;
            Ok(Value::from_float(avg))
        }),
    )
    .unwrap();

    let re = regex::Regex::new(r"([A-Z]+)(\d+)").unwrap();
    let mut final_expr = expr.to_string();

    for cap in re.captures_iter(expr) {
        let col_str = cap.get(1).map_or("", |m| m.as_str());
        let row_str = cap.get(2).map_or("", |m| m.as_str());
        
        let col = col_str.chars().fold(0, |acc, c| acc * 26 + (c as i32 - 'A' as i32 + 1)) - 1;
        let row = row_str.parse::<i32>().unwrap() - 1;

        let mut stmt = db_conn.prepare("SELECT value FROM cells WHERE row = ?1 AND col = ?2").unwrap();
        let value: Result<String, _> = stmt.query_row(params![row, col], |r| r.get(0));
        
        if let Ok(val) = value {
            if let Ok(num) = val.parse::<f64>() {
                final_expr = final_expr.replace(&cap[0], &num.to_string());
            }
        }
    }


    eval_with_context(&final_expr, &ctx)
        .map(|v| v.to_string())
        .map_err(|e| e.to_string())
}

async fn health() -> impl Responder {
    HttpResponse::Ok().body("ok")
}

async fn list_cells(data: web::Data<AppState>) -> impl Responder {
    let conn = data.db.lock().unwrap();
    let mut stmt = conn.prepare("SELECT row, col, value, font_weight, font_style, background_color FROM cells").unwrap();
    let rows = stmt
        .query_map([], |r| {
            Ok(Cell {
                row: r.get(0)?,
                col: r.get(1)?,
                value: r.get(2)?,
                font_weight: r.get(3)?,
                font_style: r.get(4)?,
                background_color: r.get(5)?,
            })
        })
        .unwrap();
    let mut cells = Vec::new();
    for r in rows {
        cells.push(r.unwrap());
    }
    HttpResponse::Ok().json(cells)
}

async fn set_cell(data: web::Data<AppState>, item: web::Json<Cell>) -> impl Responder {
    let conn = data.db.lock().unwrap();
    let mut cell_to_save = item.clone();

    if cell_to_save.value.starts_with('=') {
        if let Ok(res) = eval_formula(&cell_to_save.value, &conn) {
            cell_to_save.value = res;
        }
    }
    conn.execute(
        "INSERT INTO cells (row, col, value, font_weight, font_style, background_color) 
         VALUES (?1, ?2, ?3, ?4, ?5, ?6)
         ON CONFLICT(row, col) DO UPDATE SET 
            value=excluded.value,
            font_weight=excluded.font_weight,
            font_style=excluded.font_style,
            background_color=excluded.background_color",
        params![
            cell_to_save.row, 
            cell_to_save.col, 
            cell_to_save.value,
            cell_to_save.font_weight,
            cell_to_save.font_style,
            cell_to_save.background_color,
        ],
    ).unwrap();
    
    // Broadcast the update to all connected WebSocket sessions
    broadcast_cell_update(&data.sessions, &cell_to_save, "system".to_string());
    
    HttpResponse::Ok().body("saved")
}

async fn set_cells_bulk(data: web::Data<AppState>, items: web::Json<Vec<Cell>>) -> impl Responder {
    let conn = data.db.lock().unwrap();
    
    // Start transaction for better performance
    let tx = conn.unchecked_transaction().unwrap();
    
    for item in items.iter() {
        let mut cell_to_save = item.clone();

        if cell_to_save.value.starts_with('=') {
            if let Ok(res) = eval_formula(&cell_to_save.value, &conn) {
                cell_to_save.value = res;
            }
        }
        
        tx.execute(
            "INSERT INTO cells (row, col, value, font_weight, font_style, background_color) 
             VALUES (?1, ?2, ?3, ?4, ?5, ?6)
             ON CONFLICT(row, col) DO UPDATE SET 
                value=excluded.value,
                font_weight=excluded.font_weight,
                font_style=excluded.font_style,
                background_color=excluded.background_color",
            params![
                cell_to_save.row, 
                cell_to_save.col, 
                cell_to_save.value,
                cell_to_save.font_weight,
                cell_to_save.font_style,
                cell_to_save.background_color,
            ],
        ).unwrap();
    }
    
    tx.commit().unwrap();
    HttpResponse::Ok().body("saved")
}

#[derive(Serialize, Deserialize)]
struct EvalRequest {
    expr: String,
}

async fn evaluate(query: web::Json<EvalRequest>, data: web::Data<AppState>) -> impl Responder {
    let conn = data.db.lock().unwrap();
    match eval_formula(&query.expr, &conn) {
        Ok(result) => HttpResponse::Ok().body(result),
        Err(e) => HttpResponse::BadRequest().body(e),
    }
}

#[derive(Serialize, Deserialize)]
struct ClearRequest {
    cells: Vec<CellPosition>,
}

#[derive(Serialize, Deserialize)]
struct CellPosition {
    row: i32,
    col: i32,
}

async fn clear_cells_bulk(data: web::Data<AppState>, request: web::Json<ClearRequest>) -> impl Responder {
    let conn = data.db.lock().unwrap();
    
    // Start transaction for better performance
    let tx = conn.unchecked_transaction().unwrap();
    
    for pos in request.cells.iter() {
        tx.execute(
            "DELETE FROM cells WHERE row = ?1 AND col = ?2",
            params![pos.row, pos.col],
        ).unwrap();
    }
    
    tx.commit().unwrap();
    HttpResponse::Ok().body("cleared")
}

pub fn init_db(conn: &Connection) {
    conn.execute(
        "CREATE TABLE IF NOT EXISTS cells (
            row INTEGER,
            col INTEGER,
            value TEXT,
            font_weight TEXT,
            font_style TEXT,
            background_color TEXT,
            PRIMARY KEY (row, col)
        )",
        [],
    )
    .unwrap();
}


// WebSocket endpoint
async fn ws_index(req: HttpRequest, stream: web::Payload, data: web::Data<AppState>) -> Result<HttpResponse, actix_web::Error> {
    let session_id = Uuid::new_v4().to_string();
    let sessions = data.sessions.clone();
    
    ws::start(
        WebSocketSession {
            id: session_id,
            sessions,
        },
        &req,
        stream,
    )
}

// Helper function to broadcast cell updates
fn broadcast_cell_update(sessions: &Arc<Mutex<HashMap<String, Addr<WebSocketSession>>>>, cell: &Cell, user_id: String) {
    let update = CellUpdate {
        row: cell.row,
        col: cell.col,
        value: cell.value.clone(),
        font_weight: cell.font_weight.clone(),
        font_style: cell.font_style.clone(),
        background_color: cell.background_color.clone(),
        user_id,
    };
    
    if let Ok(msg_str) = serde_json::to_string(&update) {
        let sessions_guard = sessions.lock().unwrap();
        for (_, addr) in sessions_guard.iter() {
            addr.do_send(WebSocketMessage(msg_str.clone()));
        }
    }
}

#[actix_web::main]
async fn main() -> std::io::Result<()> {
    let conn = Connection::open("cells.db").unwrap();
    init_db(&conn);

    let data = web::Data::new(AppState { db: Mutex::new(conn), sessions: Arc::new(Mutex::new(HashMap::new())) });

    HttpServer::new(move || {
        App::new()
            .wrap(
                Cors::default()
                    .allow_any_origin()
                    .allow_any_method()
                    .allow_any_header()
            )
            .app_data(data.clone())
            .route("/health", web::get().to(health))
            .route("/cells", web::get().to(list_cells))
            .route("/cells", web::post().to(set_cell))
            .route("/cells/bulk", web::post().to(set_cells_bulk))
            .route("/cells/clear", web::post().to(clear_cells_bulk))
            .route("/evaluate", web::post().to(evaluate))
            .route("/ws", web::get().to(ws_index))
            .route("/ws", web::get().to(ws_index)) // WebSocket route
    })
    .bind(("0.0.0.0", 6889))?
    .run()
    .await
}

#[cfg(test)]
mod tests {
    use super::*;
    use actix_web::{body::to_bytes, test};

    #[actix_rt::test]
    async fn health_works() {
        let conn = Connection::open_in_memory().unwrap();
        init_db(&conn);
        let data = web::Data::new(AppState { db: Mutex::new(conn) });
        let app = test::init_service(
            App::new()
                .app_data(data.clone())
                .route("/health", web::get().to(health))
                .route("/cells", web::get().to(list_cells))
                .route("/cells", web::post().to(set_cell))
                .route("/evaluate", web::post().to(evaluate)),
        )
        .await;
        let req = test::TestRequest::get().uri("/health").to_request();
        let resp = test::call_service(&app, req).await;
        assert!(resp.status().is_success());
    }

    #[actix_rt::test]
    async fn create_and_list_cells() {
        let conn = Connection::open_in_memory().unwrap();
        init_db(&conn);
        let data = web::Data::new(AppState { db: Mutex::new(conn) });
        let app = test::init_service(
            App::new()
                .app_data(data.clone())
                .route("/health", web::get().to(health))
                .route("/cells", web::get().to(list_cells))
                .route("/cells", web::post().to(set_cell)),
        )
        .await;

        let new_cell = Cell { row: 1, col: 1, value: "42".into(), font_weight: None, font_style: None, background_color: None };
        let req = test::TestRequest::post()
            .uri("/cells")
            .set_json(&new_cell)
            .to_request();
        let resp = test::call_service(&app, req).await;
        assert!(resp.status().is_success());

        let req = test::TestRequest::get().uri("/cells").to_request();
        let resp = test::call_service(&app, req).await;
        assert!(resp.status().is_success());
        let bytes = to_bytes(resp.into_body()).await.unwrap();
        let cells: Vec<Cell> = serde_json::from_slice(&bytes).unwrap();
        assert_eq!(cells.len(), 1);
        assert_eq!(cells[0].value, "42");
    }

    #[actix_rt::test]
    async fn evaluate_formula() {
        let conn = Connection::open_in_memory().unwrap();
        init_db(&conn);
        let data = web::Data::new(AppState { db: Mutex::new(conn) });
        let app = test::init_service(
            App::new()
                .app_data(data.clone())
                .route("/evaluate", web::post().to(evaluate)),
        )
        .await;

        let req = test::TestRequest::post()
            .uri("/evaluate")
            .set_json(&EvalRequest { expr: "=SUM(1,2,3)".into() })
            .to_request();
        let resp = test::call_service(&app, req).await;
        assert!(resp.status().is_success());
        let bytes = to_bytes(resp.into_body()).await.unwrap();
        assert_eq!(&bytes[..], b"6");
    }

    #[actix_rt::test]
    async fn evaluate_average() {
        let conn = Connection::open_in_memory().unwrap();
        init_db(&conn);
        let data = web::Data::new(AppState { db: Mutex::new(conn) });
        let app = test::init_service(
            App::new()
                .app_data(data.clone())
                .route("/evaluate", web::post().to(evaluate)),
        )
        .await;

        let req = test::TestRequest::post()
            .uri("/evaluate")
            .set_json(&EvalRequest { expr: "=AVERAGE(2,4,6)".into() })
            .to_request();
        let resp = test::call_service(&app, req).await;
        assert!(resp.status().is_success());
        let bytes = to_bytes(resp.into_body()).await.unwrap();
        assert_eq!(&bytes[..], b"4");
    }

    #[actix_rt::test]
    async fn set_formula_cell() {
        let conn = Connection::open_in_memory().unwrap();
        init_db(&conn);
        let data = web::Data::new(AppState { db: Mutex::new(conn) });
        let app = test::init_service(
            App::new()
                .app_data(data.clone())
                .route("/cells", web::post().to(set_cell))
                .route("/cells", web::get().to(list_cells)),
        )
        .await;

        let new_cell = Cell { row: 1, col: 1, value: "=SUM(2,3)".into(), font_weight: None, font_style: None, background_color: None };
        let req = test::TestRequest::post()
            .uri("/cells")
            .set_json(&new_cell)
            .to_request();
        let resp = test::call_service(&app, req).await;
        assert!(resp.status().is_success());

        let req = test::TestRequest::get().uri("/cells").to_request();
        let resp = test::call_service(&app, req).await;
        let bytes = to_bytes(resp.into_body()).await.unwrap();
        let cells: Vec<Cell> = serde_json::from_slice(&bytes).unwrap();
        assert_eq!(cells[0].value, "5");
    }
}
