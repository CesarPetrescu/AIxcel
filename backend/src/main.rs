use actix_web::{web, App, HttpResponse, HttpServer, Responder};
use rusqlite::{params, Connection};
use serde::{Deserialize, Serialize};
use std::sync::Mutex;
use evalexpr::*;

pub struct AppState {
    pub db: Mutex<Connection>,
}

#[derive(Serialize, Deserialize)]
struct Cell {
    row: i32,
    col: i32,
    value: String,
}

fn eval_formula(expr: &str) -> Result<String, String> {
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

    eval_with_context(expr, &ctx)
        .map(|v| v.to_string())
        .map_err(|e| e.to_string())
}

async fn health() -> impl Responder {
    HttpResponse::Ok().body("ok")
}

async fn list_cells(data: web::Data<AppState>) -> impl Responder {
    let conn = data.db.lock().unwrap();
    let mut stmt = conn.prepare("SELECT row, col, value FROM cells").unwrap();
    let rows = stmt
        .query_map([], |r| {
            Ok(Cell {
                row: r.get(0)?,
                col: r.get(1)?,
                value: r.get(2)?,
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
    let mut value = item.value.clone();
    if value.starts_with('=') {
        if let Ok(res) = eval_formula(&value) {
            value = res;
        }
    }
    conn.execute(
        "INSERT INTO cells (row, col, value) VALUES (?1, ?2, ?3)
            ON CONFLICT(row, col) DO UPDATE SET value=excluded.value",
        params![item.row, item.col, value],
    ).unwrap();
    HttpResponse::Ok().body("saved")
}

#[derive(Serialize, Deserialize)]
struct EvalRequest {
    expr: String,
}

async fn evaluate(query: web::Json<EvalRequest>) -> impl Responder {
    match eval_formula(&query.expr) {
        Ok(result) => HttpResponse::Ok().body(result),
        Err(e) => HttpResponse::BadRequest().body(e),
    }
}

pub fn init_db(conn: &Connection) {
    conn.execute(
        "CREATE TABLE IF NOT EXISTS cells (
            row INTEGER,
            col INTEGER,
            value TEXT,
            PRIMARY KEY (row, col)
        )",
        [],
    )
    .unwrap();
}


#[actix_web::main]
async fn main() -> std::io::Result<()> {
    let conn = Connection::open("cells.db").unwrap();
    init_db(&conn);

    let data = web::Data::new(AppState { db: Mutex::new(conn) });

    HttpServer::new(move || {
        App::new()
            .app_data(data.clone())
            .route("/health", web::get().to(health))
            .route("/cells", web::get().to(list_cells))
            .route("/cells", web::post().to(set_cell))
            .route("/evaluate", web::post().to(evaluate))
    })
    .bind(("0.0.0.0", 8080))?
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

        let new_cell = Cell { row: 1, col: 1, value: "42".into() };
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

        let new_cell = Cell { row: 1, col: 1, value: "=SUM(2,3)".into() };
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
