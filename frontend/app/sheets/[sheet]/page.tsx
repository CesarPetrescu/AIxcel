"use client";
import { useEffect, useState } from "react";
import { useParams } from "next/navigation";
import styles from "../../page.module.css";

interface Cell {
  row: number;
  col: number;
  value: string;
  font_weight?: string;
  font_style?: string;
  background_color?: string;
}

// Dynamic infinite grid - no more hardcoded limits
const ROW_HEIGHT = 25;
const HEADER_HEIGHT = 30;
const COL_WIDTH = 80;
const HEADER_WIDTH = 50;

// Calculate visible area based on viewport
const getVisibleArea = (containerWidth: number, containerHeight: number, scrollLeft: number, scrollTop: number) => {
  const startRow = Math.max(0, Math.floor(scrollTop / ROW_HEIGHT));
  const endRow = startRow + Math.ceil(containerHeight / ROW_HEIGHT) + 5; // +5 for buffer
  const startCol = Math.max(0, Math.floor(scrollLeft / COL_WIDTH));
  const endCol = startCol + Math.ceil(containerWidth / COL_WIDTH) + 5; // +5 for buffer
  
  return { startRow, endRow, startCol, endCol };
};

export default function SheetPage() {
  const params = useParams<{ sheet: string }>();
  const sheet = params.sheet || 'default';

  const [cells, setCells] = useState<Cell[]>([]);
  const [selectedCells, setSelectedCells] = useState<{row: number, col: number}[]>([]);
  const [primarySelection, setPrimarySelection] = useState<{row: number, col: number} | null>(null);
  const [selectionStart, setSelectionStart] = useState<{row: number, col: number} | null>(null);
  const [isSelecting, setIsSelecting] = useState(false);
  const [editingCell, setEditingCell] = useState<{row: number, col: number} | null>(null);
  const [editValue, setEditValue] = useState("");
  const [formula, setFormula] = useState("");
  const [currentFormatting, setCurrentFormatting] = useState<{
    font_weight?: string;
    font_style?: string;
    background_color?: string;
  }>({});
  const [contextMenu, setContextMenu] = useState<{x: number, y: number, row: number, col: number} | null>(null);
  const [isExtending, setIsExtending] = useState(false);
  const [extensionStart, setExtensionStart] = useState<{row: number, col: number} | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [evaluationResult, setEvaluationResult] = useState<string | null>(null);
  
  // Dynamic grid state
  const [containerSize, setContainerSize] = useState({ width: 1200, height: 800 });
  const [scrollPosition, setScrollPosition] = useState({ left: 0, top: 0 });
  const [visibleArea, setVisibleArea] = useState({ startRow: 0, endRow: 30, startCol: 0, endCol: 15 });
  
  // WebSocket state
  const [, setWs] = useState<WebSocket | null>(null);
  const [isConnected, setIsConnected] = useState(false);
  const [connectedUsers, setConnectedUsers] = useState<string[]>([]);

  // WebSocket connection setup
  useEffect(() => {
    // Use the configured backend URL for WebSocket connection
    const backendUrl = process.env.NEXT_PUBLIC_API_BASE_URL || 'http://192.168.10.161:6889';
    const wsUrl = backendUrl.replace('http', 'ws') + '/ws';
    const websocket = new WebSocket(wsUrl);
    
    websocket.onopen = () => {
      console.log('WebSocket connected');
      setIsConnected(true);
    };
    
    websocket.onmessage = (event) => {
      try {
        const data = JSON.parse(event.data);
        
        if (data.row !== undefined && data.col !== undefined) {
          // Cell update from another user
          setCells(prev => {
            const existing = prev.findIndex(c => c.row === data.row && c.col === data.col);
            if (existing >= 0) {
              const updated = [...prev];
              updated[existing] = { ...updated[existing], ...data };
              return updated;
            } else {
              return [...prev, data];
            }
          });
        } else if (data.user_id) {
          // User joined/left events
          if (data.type === 'UserJoined') {
            setConnectedUsers(prev => [...prev, data.user_id]);
          } else if (data.type === 'UserLeft') {
            setConnectedUsers(prev => prev.filter(id => id !== data.user_id));
          }
        }
      } catch (error) {
        console.error('Error parsing WebSocket message:', error);
      }
    };
    
    websocket.onclose = () => {
      console.log('WebSocket disconnected');
      setIsConnected(false);
      setConnectedUsers([]);
    };
    
    setWs(websocket);
    
    return () => {
      websocket.close();
    };
  }, []);

  // Update visible area when scrolling or container size changes
  useEffect(() => {
    const newVisibleArea = getVisibleArea(
      containerSize.width,
      containerSize.height,
      scrollPosition.left,
      scrollPosition.top
    );
    setVisibleArea(newVisibleArea);
  }, [containerSize, scrollPosition]);

  // Initial data fetch
  useEffect(() => {
    if (typeof window !== 'undefined') {
      setIsLoading(true);
      setError(null);
      const url = `/api/cells?sheet=${sheet}`;
      fetch(url)
        .then((res) => {
          if (!res.ok) throw new Error('Failed to fetch cells');
          return res.json();
        })
        .then((data) => {
          setCells(data);
          setIsLoading(false);
        })
        .catch((err) => {
          console.error('Error fetching cells:', err);
          setError('Failed to load spreadsheet data');
          setIsLoading(false);
        });
    }
  }, [sheet]);

  // Handle container resize
  useEffect(() => {
    const handleResize = () => {
      const container = document.querySelector(`.${styles.spreadsheetContainer}`) as HTMLElement;
      if (container) {
        setContainerSize({
          width: container.clientWidth,
          height: container.clientHeight
        });
      }
    };

    handleResize(); // Initial size
    window.addEventListener('resize', handleResize);
    return () => window.removeEventListener('resize', handleResize);
  }, []);

  useEffect(() => {
    const handleClickOutside = () => setContextMenu(null);
    document.addEventListener('click', handleClickOutside);
    return () => document.removeEventListener('click', handleClickOutside);
  }, []);

  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      if (editingCell) return; // Don't handle global keys when editing a cell

      // Arrow key navigation
      if (primarySelection && ['ArrowUp', 'ArrowDown', 'ArrowLeft', 'ArrowRight'].includes(e.key)) {
        e.preventDefault();
        let newRow = primarySelection.row;
        let newCol = primarySelection.col;

        if (e.key === 'ArrowUp') newRow = Math.max(0, newRow - 1);
        else if (e.key === 'ArrowDown') newRow = newRow + 1;
        else if (e.key === 'ArrowLeft') newCol = Math.max(0, newCol - 1);
        else if (e.key === 'ArrowRight') newCol = newCol + 1;

        if (e.shiftKey) {
          // Extend selection with shift+arrow
          const range = getRangeFromStartToEnd(selectionStart || primarySelection, { row: newRow, col: newCol });
          setSelectedCells(range);
          setPrimarySelection({ row: newRow, col: newCol });
          if (!selectionStart) setSelectionStart(primarySelection);
        } else {
          // Move selection
          selectSingleCell(newRow, newCol);
          setSelectionStart(null);
        }
        return;
      }

      // Enter key to edit cell
      if (primarySelection && e.key === 'Enter') {
        e.preventDefault();
        setEditingCell(primarySelection);
        setEditValue(getCellValue(primarySelection.row, primarySelection.col));
        return;
      }

      if (primarySelection && e.key.length === 1 && !e.ctrlKey && !e.metaKey) {
        e.preventDefault();
        setEditingCell(primarySelection);
        setEditValue(e.key);
        return;
      }

      if (e.key === 'Delete' || e.key === 'Backspace') {
        clearSelectedCells();
      } else if (e.key === 'Escape') {
        clearSelection();
      } else if (e.ctrlKey || e.metaKey) {
        if (e.key === 'a' || e.key === 'A') {
          e.preventDefault();
          selectAllCells();
        } else if (e.key === 'c' || e.key === 'C') {
          e.preventDefault();
          copySelectedCells();
        }
      }
    };

    document.addEventListener('keydown', handleKeyDown);
    return () => document.removeEventListener('keydown', handleKeyDown);
  }, [selectedCells, editingCell, primarySelection, selectionStart]);

  const getCellValue = (row: number, col: number) => {
    const cell = cells.find(c => c.row === row && c.col === col);
    return cell?.value || "";
  };

  const getCellFormatting = (row: number, col: number) => {
    const cell = cells.find(c => c.row === row && c.col === col);
    return {
      font_weight: cell?.font_weight,
      font_style: cell?.font_style,
      background_color: cell?.background_color,
    };
  };

  // Helper functions for multi-cell selection
  const isCellSelected = (row: number, col: number) => {
    return selectedCells.some(cell => cell.row === row && cell.col === col);
  };

  const isPrimarySelection = (row: number, col: number) => {
    return primarySelection?.row === row && primarySelection?.col === col;
  };

  const getRangeFromStartToEnd = (start: {row: number, col: number}, end: {row: number, col: number}) => {
    const minRow = Math.min(start.row, end.row);
    const maxRow = Math.max(start.row, end.row);
    const minCol = Math.min(start.col, end.col);
    const maxCol = Math.max(start.col, end.col);

    const range: {row: number, col: number}[] = [];
    for (let r = minRow; r <= maxRow; r++) {
      for (let c = minCol; c <= maxCol; c++) {
        range.push({ row: r, col: c });
      }
    }
    return range;
  };

  const addCellToSelection = (row: number, col: number) => {
    if (!isCellSelected(row, col)) {
      setSelectedCells(prev => [...prev, { row, col }]);
    }
  };

  const removeCellFromSelection = (row: number, col: number) => {
    setSelectedCells(prev => prev.filter(cell => !(cell.row === row && cell.col === col)));
  };

  const clearSelection = () => {
    setSelectedCells([]);
    setPrimarySelection(null);
  };

  const selectSingleCell = (row: number, col: number) => {
    setSelectedCells([{ row, col }]);
    setPrimarySelection({ row, col });
  };

  const selectAllCells = () => {
    const allCells: {row: number, col: number}[] = [];
    // Select all visible cells plus a reasonable buffer
    const maxRow = Math.max(visibleArea.endRow, 100);
    const maxCol = Math.max(visibleArea.endCol, 26);

    for (let r = 0; r < maxRow; r++) {
      for (let c = 0; c < maxCol; c++) {
        allCells.push({ row: r, col: c });
      }
    }
    setSelectedCells(allCells);
    setPrimarySelection({ row: 0, col: 0 });
  };

  const clearSelectedCells = async () => {
    if (selectedCells.length === 0) return;
    
    await clearCellsBulk(selectedCells);
  };

  const copySelectedCells = () => {
    if (!primarySelection) return;
    const value = getCellValue(primarySelection.row, primarySelection.col);
    navigator.clipboard.writeText(value);
  };

  // Helper function to detect patterns in selected values
  // Currently unused but will be used for auto-fill functionality
  // eslint-disable-next-line @typescript-eslint/no-unused-vars
  const detectPattern = (values: string[]): string[] => {
    if (values.length === 0) return [""];
    if (values.length === 1) return [values[0]]; // Repeat single value
    
    // Clean up values (trim whitespace)
    const cleanValues = values.map(v => v.trim()).filter(v => v !== "");
    if (cleanValues.length === 0) return [""];
    
    // 1. Pure numeric sequence detection
    const numbers = cleanValues.map(v => parseFloat(v)).filter(n => !isNaN(n));
    if (numbers.length === cleanValues.length && numbers.length >= 2) {
      // Check for arithmetic progression (constant difference)
      const differences: number[] = [];
      for (let i = 1; i < numbers.length; i++) {
        differences.push(numbers[i] - numbers[i - 1]);
      }
      
      // Check if differences are consistent (arithmetic sequence)
      if (differences.every(d => Math.abs(d - differences[0]) < 0.0001)) {
        const diff = differences[0];
        const lastNum = numbers[numbers.length - 1];
        return [String(lastNum + diff)];
      }
      
      // Check for geometric progression (constant ratio)
      if (numbers.every(n => n !== 0)) {
        const ratios: number[] = [];
        for (let i = 1; i < numbers.length; i++) {
          ratios.push(numbers[i] / numbers[i - 1]);
        }
        
        if (ratios.every(r => Math.abs(r - ratios[0]) < 0.0001)) {
          const ratio = ratios[0];
          const lastNum = numbers[numbers.length - 1];
          return [String(Math.round(lastNum * ratio * 100) / 100)];
        }
      }
      
      // Fibonacci-like sequence detection
      if (numbers.length >= 3) {
        let isFibonacci = true;
        for (let i = 2; i < numbers.length; i++) {
          if (Math.abs(numbers[i] - (numbers[i-1] + numbers[i-2])) > 0.0001) {
            isFibonacci = false;
            break;
          }
        }
        if (isFibonacci) {
          const nextFib = numbers[numbers.length - 1] + numbers[numbers.length - 2];
          return [String(nextFib)];
        }
      }
    }
    
    // 2. Date pattern detection
    const datePattern = /^(\d{1,2})[\/\-](\d{1,2})[\/\-](\d{2,4})$/;
    if (cleanValues.every(v => datePattern.test(v))) {
      try {
        const dates = cleanValues.map(v => {
          const match = v.match(datePattern);
          if (match) {
            const [, month, day, year] = match;
            return new Date(parseInt(year), parseInt(month) - 1, parseInt(day));
          }
          return null;
        }).filter(d => d !== null) as Date[];
        
        if (dates.length >= 2) {
          const dayDiff = (dates[1].getTime() - dates[0].getTime()) / (1000 * 60 * 60 * 24);
          const lastDate = dates[dates.length - 1];
          const nextDate = new Date(lastDate.getTime() + dayDiff * 24 * 60 * 60 * 1000);
          return [`${nextDate.getMonth() + 1}/${nextDate.getDate()}/${nextDate.getFullYear()}`];
        }
      } catch {
        // Fall through to other patterns
      }
    }
    
    // 3. Day of week pattern
    const days = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
    const dayAbbr = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];
    const lowerValues = cleanValues.map(v => v.toLowerCase());
    
    if (lowerValues.every(v => days.includes(v))) {
      const lastDayIndex = days.indexOf(lowerValues[lowerValues.length - 1]);
      const nextDayIndex = (lastDayIndex + 1) % 7;
      return [cleanValues[0][0].toUpperCase() + days[nextDayIndex].slice(1)];
    }
    
    if (lowerValues.every(v => dayAbbr.includes(v))) {
      const lastDayIndex = dayAbbr.indexOf(lowerValues[lowerValues.length - 1]);
      const nextDayIndex = (lastDayIndex + 1) % 7;
      const nextDay = dayAbbr[nextDayIndex];
      return [cleanValues[0][0].toUpperCase() + nextDay.slice(1)];
    }
    
    // 4. Month pattern
    const months = ['january', 'february', 'march', 'april', 'may', 'june', 
                   'july', 'august', 'september', 'october', 'november', 'december'];
    const monthAbbr = ['jan', 'feb', 'mar', 'apr', 'may', 'jun',
                      'jul', 'aug', 'sep', 'oct', 'nov', 'dec'];
    
    if (lowerValues.every(v => months.includes(v))) {
      const lastMonthIndex = months.indexOf(lowerValues[lowerValues.length - 1]);
      const nextMonthIndex = (lastMonthIndex + 1) % 12;
      return [cleanValues[0][0].toUpperCase() + months[nextMonthIndex].slice(1)];
    }
    
    if (lowerValues.every(v => monthAbbr.includes(v))) {
      const lastMonthIndex = monthAbbr.indexOf(lowerValues[lowerValues.length - 1]);
      const nextMonthIndex = (lastMonthIndex + 1) % 12;
      const nextMonth = monthAbbr[nextMonthIndex];
      return [cleanValues[0][0].toUpperCase() + nextMonth.slice(1)];
    }
    
    // 5. Text with number pattern (e.g., "Item 1", "Item 2")
    const textNumberPattern = /^(.+?)(\d+)(.*)$/;
    if (cleanValues.every(v => textNumberPattern.test(v))) {
      const matches = cleanValues.map(v => v.match(textNumberPattern));
      const prefixes = matches.map(m => m?.[1] || "");
      const suffixes = matches.map(m => m?.[3] || "");
      const numbers = matches.map(m => parseInt(m?.[2] || "0"));
      
      // Check if prefixes and suffixes are consistent
      if (prefixes.every(p => p === prefixes[0]) && suffixes.every(s => s === suffixes[0])) {
        // Check for arithmetic progression in numbers
        const numDifferences: number[] = [];
        for (let i = 1; i < numbers.length; i++) {
          numDifferences.push(numbers[i] - numbers[i - 1]);
        }
        
        if (numDifferences.every(d => d === numDifferences[0])) {
          const diff = numDifferences[0];
          const lastNum = numbers[numbers.length - 1];
          const nextNum = lastNum + diff;
          return [`${prefixes[0]}${nextNum}${suffixes[0]}`];
        }
      }
    }
    
    // 6. Letter sequence (A, B, C...)
    if (cleanValues.every(v => /^[A-Za-z]$/.test(v))) {
      const isUpperCase = cleanValues[0] === cleanValues[0].toUpperCase();
      const letters = cleanValues.map(v => v.toUpperCase().charCodeAt(0) - 'A'.charCodeAt(0));

      if (letters.length >= 2) {
        const diff = letters[1] - letters[0];
        if (letters.every((l, i) => i === 0 || l - letters[i-1] === diff)) {
          const lastLetterCode = letters[letters.length - 1];
          const nextLetterCode = lastLetterCode + diff;
          if (nextLetterCode >= 0 && nextLetterCode < 26) {
            const nextLetter = String.fromCharCode('A'.charCodeAt(0) + nextLetterCode);
            return [isUpperCase ? nextLetter : nextLetter.toLowerCase()];
          } else {
            return [cleanValues[cleanValues.length - 1]];
          }
        }
      }
    }
    
    // 7. Roman numerals (basic)
    const romanNumerals = ['I', 'II', 'III', 'IV', 'V', 'VI', 'VII', 'VIII', 'IX', 'X', 
                          'XI', 'XII', 'XIII', 'XIV', 'XV', 'XVI', 'XVII', 'XVIII', 'XIX', 'XX'];
    const upperValues = cleanValues.map(v => v.toUpperCase());
    if (upperValues.every(v => romanNumerals.includes(v))) {
      const lastIndex = romanNumerals.indexOf(upperValues[upperValues.length - 1]);
      if (lastIndex >= 0 && lastIndex < romanNumerals.length - 1) {
        const nextRoman = romanNumerals[lastIndex + 1];
        return [cleanValues[0] === cleanValues[0].toLowerCase() ? nextRoman.toLowerCase() : nextRoman];
      }
    }
    
    // 8. Repeating pattern detection
    if (cleanValues.length >= 4) {
      // Check for 2-element repeating pattern
      let is2Pattern = true;
      for (let i = 2; i < cleanValues.length; i++) {
        if (cleanValues[i] !== cleanValues[i % 2]) {
          is2Pattern = false;
          break;
        }
      }
      if (is2Pattern) {
        return [cleanValues[cleanValues.length % 2]];
      }
      
      // Check for 3-element repeating pattern
      if (cleanValues.length >= 6) {
        let is3Pattern = true;
        for (let i = 3; i < cleanValues.length; i++) {
          if (cleanValues[i] !== cleanValues[i % 3]) {
            is3Pattern = false;
            break;
          }
        }
        if (is3Pattern) {
          return [cleanValues[cleanValues.length % 3]];
        }
      }
    }
    
    // 9. Default: Increment last number found in string, or repeat
    const lastValue = cleanValues[cleanValues.length - 1];
    const numberMatch = lastValue.match(/(\d+)/g);
    if (numberMatch) {
      const lastNumber = numberMatch[numberMatch.length - 1];
      const nextNumber = String(parseInt(lastNumber) + 1);
      return [lastValue.replace(new RegExp(lastNumber + '(?!.*\\d)'), nextNumber)];
    }
    
    // Default: repeat the last value
    return [lastValue];
  };

  const generateSequence = (values: string[], count: number): string[] => {
    if (values.length === 0) return Array(count).fill("");
    if (values.length === 1) return Array(count).fill(values[0]);

    const cleanValues = values.map(v => v.trim()).filter(v => v !== "");
    if (cleanValues.length === 0) return Array(count).fill("");

    const result: string[] = [];

    // Detect the pattern type and generate accordingly
    const numbers = cleanValues.map(v => parseFloat(v)).filter(n => !isNaN(n));

    // Numeric arithmetic sequence
    if (numbers.length === cleanValues.length && numbers.length >= 2) {
      const differences: number[] = [];
      for (let i = 1; i < numbers.length; i++) {
        differences.push(numbers[i] - numbers[i - 1]);
      }

      if (differences.every(d => Math.abs(d - differences[0]) < 0.0001)) {
        const diff = differences[0];
        let lastNum = numbers[numbers.length - 1];
        for (let i = 0; i < count; i++) {
          lastNum += diff;
          result.push(String(lastNum));
        }
        return result;
      }
    }
    
    // Text with number pattern
    const textNumberPattern = /^(.+?)(\d+)(.*)$/;
    if (cleanValues.every(v => textNumberPattern.test(v))) {
      const matches = cleanValues.map(v => v.match(textNumberPattern));
      const prefixes = matches.map(m => m?.[1] || "");
      const suffixes = matches.map(m => m?.[3] || "");
      const nums = matches.map(m => parseInt(m?.[2] || "0"));
      
      if (prefixes.every(p => p === prefixes[0]) && suffixes.every(s => s === suffixes[0])) {
        const numDifferences: number[] = [];
        for (let i = 1; i < nums.length; i++) {
          numDifferences.push(nums[i] - nums[i - 1]);
        }
        
        if (numDifferences.every(d => d === numDifferences[0])) {
          const diff = numDifferences[0];
          let lastNum = nums[nums.length - 1];
          for (let i = 0; i < count; i++) {
            lastNum += diff;
            result.push(`${prefixes[0]}${lastNum}${suffixes[0]}`);
          }
          return result;
        }
      }
    }
    
    // Day sequence
    const days = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
    const dayAbbr = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];
    const lowerValues = cleanValues.map(v => v.toLowerCase());
    
    if (lowerValues.every(v => days.includes(v))) {
      let lastDayIndex = days.indexOf(lowerValues[lowerValues.length - 1]);
      for (let i = 0; i < count; i++) {
        lastDayIndex = (lastDayIndex + 1) % 7;
        const nextDay = days[lastDayIndex];
        result.push(cleanValues[0][0].toUpperCase() + nextDay.slice(1));
      }
      return result;
    }
    
    if (lowerValues.every(v => dayAbbr.includes(v))) {
      let lastDayIndex = dayAbbr.indexOf(lowerValues[lowerValues.length - 1]);
      for (let i = 0; i < count; i++) {
        lastDayIndex = (lastDayIndex + 1) % 7;
        const nextDay = dayAbbr[lastDayIndex];
        result.push(cleanValues[0][0].toUpperCase() + nextDay.slice(1));
      }
      return result;
    }
    
    // Month sequence
    const months = ['january', 'february', 'march', 'april', 'may', 'june', 
                   'july', 'august', 'september', 'october', 'november', 'december'];
    const monthAbbr = ['jan', 'feb', 'mar', 'apr', 'may', 'jun',
                      'jul', 'aug', 'sep', 'oct', 'nov', 'dec'];
    
    if (lowerValues.every(v => months.includes(v))) {
      let lastMonthIndex = months.indexOf(lowerValues[lowerValues.length - 1]);
      for (let i = 0; i < count; i++) {
        lastMonthIndex = (lastMonthIndex + 1) % 12;
        const nextMonth = months[lastMonthIndex];
        result.push(cleanValues[0][0].toUpperCase() + nextMonth.slice(1));
      }
      return result;
    }
    
    if (lowerValues.every(v => monthAbbr.includes(v))) {
      let lastMonthIndex = monthAbbr.indexOf(lowerValues[lowerValues.length - 1]);
      for (let i = 0; i < count; i++) {
        lastMonthIndex = (lastMonthIndex + 1) % 12;
        const nextMonth = monthAbbr[lastMonthIndex];
        result.push(cleanValues[0][0].toUpperCase() + nextMonth.slice(1));
      }
      return result;
    }
    
    // Letter sequence
    if (cleanValues.every(v => /^[A-Za-z]$/.test(v))) {
      const isUpperCase = cleanValues[0] === cleanValues[0].toUpperCase();
      const letters = cleanValues.map(v => v.toUpperCase().charCodeAt(0) - 'A'.charCodeAt(0));
      
      if (letters.length >= 2) {
        const diff = letters[1] - letters[0];
        if (letters.every((l, i) => i === 0 || l - letters[i-1] === diff)) {
          let lastLetterCode = letters[letters.length - 1];
          for (let i = 0; i < count; i++) {
            lastLetterCode += diff;
            if (lastLetterCode >= 0 && lastLetterCode < 26) {
              const nextLetter = String.fromCharCode('A'.charCodeAt(0) + lastLetterCode);
              result.push(isUpperCase ? nextLetter : nextLetter.toLowerCase());
            } else {
              result.push(cleanValues[cleanValues.length - 1]);
            }
          }
          return result;
        }
      }
    }
    
    // Default: repeat the last value or increment numbers
    const lastValue = cleanValues[cleanValues.length - 1];
    const numberMatch = lastValue.match(/(\d+)/g);
    
    if (numberMatch) {
      const lastNumber = numberMatch[numberMatch.length - 1];
      let num = parseInt(lastNumber);
      for (let i = 0; i < count; i++) {
        num++;
        const nextValue = lastValue.replace(new RegExp(lastNumber + '(?!.*\\d)'), String(num));
        result.push(nextValue);
      }
      return result;
    }
    
    // Fallback: repeat last value
    return Array(count).fill(lastValue);
  };

  const extendSelection = async (targetRow: number, targetCol: number) => {
    if (!primarySelection || selectedCells.length === 0) return;
    
    // Get the current selection bounds
    const minRow = Math.min(...selectedCells.map(c => c.row));
    const maxRow = Math.max(...selectedCells.map(c => c.row));
    const minCol = Math.min(...selectedCells.map(c => c.col));
    const maxCol = Math.max(...selectedCells.map(c => c.col));
    
    // Determine extension direction
    const extendRight = targetCol > maxCol;
    const extendDown = targetRow > maxRow;
    // const extendLeft = targetCol < minCol;
    // const extendUp = targetRow < minRow;
    
    const cellsToUpdate: Cell[] = [];
    
    if (extendRight) {
      // Extend to the right
      for (let r = minRow; r <= maxRow; r++) {
        const rowValues: string[] = [];
        for (let c = minCol; c <= maxCol; c++) {
          rowValues.push(getCellValue(r, c));
        }
        const extensionCount = targetCol - maxCol;
        const sequence = generateSequence(rowValues, extensionCount);
        
        for (let c = maxCol + 1; c <= targetCol; c++) {
          const sequenceIndex = c - maxCol - 1;
          cellsToUpdate.push({
            row: r,
            col: c,
            value: sequence[sequenceIndex] || sequence[sequence.length - 1] || "",
          });
        }
      }
    } else if (extendDown) {
      // Extend downward
      for (let c = minCol; c <= maxCol; c++) {
        const colValues: string[] = [];
        for (let r = minRow; r <= maxRow; r++) {
          colValues.push(getCellValue(r, c));
        }
        const extensionCount = targetRow - maxRow;
        const sequence = generateSequence(colValues, extensionCount);
        
        for (let r = maxRow + 1; r <= targetRow; r++) {
          const sequenceIndex = r - maxRow - 1;
          cellsToUpdate.push({
            row: r,
            col: c,
            value: sequence[sequenceIndex] || sequence[sequence.length - 1] || "",
          });
        }
      }
    }
    
    // Bulk update all new cells
    if (cellsToUpdate.length > 0) {
      await updateCellsBulk(cellsToUpdate);
    }
    
    // Update selection to include the extended range
    const newSelection = getRangeFromStartToEnd(
      { row: Math.min(minRow, targetRow), col: Math.min(minCol, targetCol) },
      { row: Math.max(maxRow, targetRow), col: Math.max(maxCol, targetCol) }
    );
    setSelectedCells(newSelection);
  };

  const updateCell = async (row: number, col: number, value: string, formatting?: {
    font_weight?: string;
    font_style?: string;
    background_color?: string;
  }) => {
    const cellData = {
      row,
      col,
      value,
      font_weight: formatting?.font_weight,
      font_style: formatting?.font_style,
      background_color: formatting?.background_color,
    };

    const url = '/api/cells';
    try {
      const response = await fetch(url, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ ...cellData, sheet }),
      });

      if (!response.ok) {
        const errorText = await response.text();
        setError(`Failed to update cell: ${errorText}`);
        setTimeout(() => setError(null), 5000);
        return;
      }

      // Only update UI if the request succeeded
      setCells(prev => {
        const idx = prev.findIndex(c => c.row === row && c.col === col);
        const updated = { ...cellData } as Cell;
        if (idx >= 0) {
          const arr = [...prev];
          arr[idx] = { ...arr[idx], ...updated };
          return arr;
        }
        return [...prev, updated];
      });
    } catch (err) {
      setError(`Failed to update cell: ${err instanceof Error ? err.message : 'Network error'}`);
      setTimeout(() => setError(null), 5000);
    }
  };

  const updateCellsBulk = async (cellsToUpdate: Cell[]) => {
    const url = '/api/cells/bulk';
    try {
      const response = await fetch(url, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(cellsToUpdate.map(c => ({ ...c, sheet }))),
      });

      if (!response.ok) {
        const errorText = await response.text();
        setError(`Failed to update cells: ${errorText}`);
        setTimeout(() => setError(null), 5000);
        return;
      }

      // Only update UI if the request succeeded
      setCells(prev => {
        const map = new Map(prev.map(c => [`${c.row}-${c.col}`, c]));
        cellsToUpdate.forEach(c => {
          map.set(`${c.row}-${c.col}`, { ...c });
        });
        return Array.from(map.values());
      });
    } catch (err) {
      setError(`Failed to update cells: ${err instanceof Error ? err.message : 'Network error'}`);
      setTimeout(() => setError(null), 5000);
    }
  };

  const clearCellsBulk = async (positions: {row: number, col: number}[]) => {
    const url = '/api/cells/clear';
    try {
      const response = await fetch(url, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ cells: positions.map(p => ({ ...p, sheet })) }),
      });

      if (!response.ok) {
        const errorText = await response.text();
        setError(`Failed to clear cells: ${errorText}`);
        setTimeout(() => setError(null), 5000);
        return;
      }

      // Only update UI if the request succeeded
      setCells(prev => prev.filter(c => !positions.some(p => p.row === c.row && p.col === c.col)));
    } catch (err) {
      setError(`Failed to clear cells: ${err instanceof Error ? err.message : 'Network error'}`);
      setTimeout(() => setError(null), 5000);
    }
  };

  const handleCellClick = (row: number, col: number, event?: React.MouseEvent) => {
    setContextMenu(null);
    setEditingCell(null);
    
    if (event?.ctrlKey || event?.metaKey) {
      // Ctrl+click: toggle cell in selection
      if (isCellSelected(row, col)) {
        removeCellFromSelection(row, col);
        if (isPrimarySelection(row, col)) {
          setPrimarySelection(selectedCells.find(cell => !(cell.row === row && cell.col === col)) || null);
        }
      } else {
        addCellToSelection(row, col);
        setPrimarySelection({ row, col });
      }
    } else if (event?.shiftKey && primarySelection) {
      // Shift+click: select range from primary selection to clicked cell
      const range = getRangeFromStartToEnd(primarySelection, { row, col });
      setSelectedCells(range);
    } else {
      // Regular click: select single cell
      selectSingleCell(row, col);
    }
    
    // Update current formatting based on primary selection
    const primary = primarySelection || { row, col };
    setCurrentFormatting(getCellFormatting(primary.row, primary.col));
  };

  const handleCellMouseDown = (row: number, col: number, event: React.MouseEvent) => {
    if (event.shiftKey || event.ctrlKey || event.metaKey) return;
    
    setIsSelecting(true);
    setSelectionStart({ row, col });
    selectSingleCell(row, col);
  };

  const handleCellMouseOver = (row: number, col: number) => {
    if (isSelecting && selectionStart) {
      const range = getRangeFromStartToEnd(selectionStart, { row, col });
      setSelectedCells(range);
      setPrimarySelection(selectionStart);
    }
  };

  const handleCellMouseUp = () => {
    setIsSelecting(false);
    setSelectionStart(null);
    setIsExtending(false);
    setExtensionStart(null);
  };

  const handleExtensionStart = (e: React.MouseEvent) => {
    e.stopPropagation();
    if (selectedCells.length === 0) return;
    
    setIsExtending(true);
    const bounds = getSelectionBounds();
    setExtensionStart({ row: bounds.maxRow, col: bounds.maxCol });
  };

  const handleExtensionOver = () => {
    if (isExtending && extensionStart) {
      // Show preview of extension (you could add visual feedback here)
    }
  };

  const handleExtensionEnd = async (row: number, col: number) => {
    if (isExtending && extensionStart) {
      await extendSelection(row, col);
      setIsExtending(false);
      setExtensionStart(null);
    }
  };

  const getSelectionBounds = () => {
    if (selectedCells.length === 0) return { minRow: 0, maxRow: 0, minCol: 0, maxCol: 0 };
    
    return {
      minRow: Math.min(...selectedCells.map(c => c.row)),
      maxRow: Math.max(...selectedCells.map(c => c.row)),
      minCol: Math.min(...selectedCells.map(c => c.col)),
      maxCol: Math.max(...selectedCells.map(c => c.col))
    };
  };

  const handleCellRightClick = (e: React.MouseEvent, row: number, col: number) => {
    e.preventDefault();
    selectSingleCell(row, col);

    // Calculate context menu position with bounds checking
    const menuWidth = 160; // Approximate width of context menu
    const menuHeight = 200; // Approximate height of context menu
    const windowWidth = window.innerWidth;
    const windowHeight = window.innerHeight;

    let x = e.clientX;
    let y = e.clientY;

    // Adjust if menu would go off-screen
    if (x + menuWidth > windowWidth) {
      x = windowWidth - menuWidth - 10;
    }
    if (y + menuHeight > windowHeight) {
      y = windowHeight - menuHeight - 10;
    }

    setContextMenu({ x, y, row, col });
  };

  const handleCellDoubleClick = (row: number, col: number) => {
    selectSingleCell(row, col);
    setEditingCell({ row, col });
    setEditValue(getCellValue(row, col));
  };

  const handleCellEdit = (value: string) => {
    setEditValue(value);
  };

  const handleCellSubmit = async () => {
    if (editingCell) {
      const existingFormatting = getCellFormatting(editingCell.row, editingCell.col);
      await updateCell(editingCell.row, editingCell.col, editValue, existingFormatting);
      setEditingCell(null);
      setEditValue("");
    }
  };

  const handleCellKeyDown = (e: React.KeyboardEvent) => {
    if (e.key === 'Enter') {
      handleCellSubmit();
    } else if (e.key === 'Escape') {
      setEditingCell(null);
      setEditValue("");
    }
  };

  const getColumnLabel = (col: number) => {
    let result = '';
    while (col >= 0) {
      result = String.fromCharCode(65 + (col % 26)) + result;
      col = Math.floor(col / 26) - 1;
    }
    return result;
  };

  const applyFormatting = async (formatType: string, value: string) => {
    if (selectedCells.length === 0) return;
    
    // Prepare bulk update
    const cellsToUpdate = selectedCells.map(cell => {
      const currentFormatting = getCellFormatting(cell.row, cell.col);
      const newFormatting = { ...currentFormatting };
      
      if (formatType === 'font_weight') {
        newFormatting.font_weight = newFormatting.font_weight === 'bold' ? 'normal' : 'bold';
      } else if (formatType === 'font_style') {
        newFormatting.font_style = newFormatting.font_style === 'italic' ? 'normal' : 'italic';
      } else if (formatType === 'background_color') {
        newFormatting.background_color = value;
      }
      
      return {
        row: cell.row,
        col: cell.col,
        value: getCellValue(cell.row, cell.col),
        font_weight: newFormatting.font_weight,
        font_style: newFormatting.font_style,
        background_color: newFormatting.background_color,
      };
    });
    
    // Send bulk update
    await updateCellsBulk(cellsToUpdate);
    
    // Update current formatting based on primary selection
    if (primarySelection) {
      setCurrentFormatting(getCellFormatting(primarySelection.row, primarySelection.col));
    }
  };

  // const copyCell = () => {
  //   if (!primarySelection) return;
  //   const value = getCellValue(primarySelection.row, primarySelection.col);
  //   navigator.clipboard.writeText(value);
  //   setContextMenu(null);
  // };

  // const clearCell = async () => {
  //   if (selectedCells.length === 0) return;
    
  //   // Clear all selected cells
  //   for (const cell of selectedCells) {
  //     await updateCell(cell.row, cell.col, "");
  //   }
  //   setContextMenu(null);
  // };

  const evaluateFormula = async () => {
    if (!formula) return;

    try {
      const url = '/api/evaluate';
      const res = await fetch(url, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ expr: formula, sheet }),
      });

      if (!res.ok) {
        const errorText = await res.text();
        setEvaluationResult(`Error: ${errorText}`);
        setTimeout(() => setEvaluationResult(null), 5000);
        return;
      }

      const result = await res.text();
      setEvaluationResult(`Result: ${result}`);

      // If a cell is selected, optionally insert the result
      if (primarySelection) {
        const confirmInsert = confirm(`Result: ${result}\n\nDo you want to insert this result into the selected cell?`);
        if (confirmInsert) {
          await updateCell(primarySelection.row, primarySelection.col, result);
          setFormula('');
        }
      }

      // Clear evaluation result after 5 seconds
      setTimeout(() => setEvaluationResult(null), 5000);
    } catch (err) {
      setEvaluationResult(`Error: ${err instanceof Error ? err.message : 'Unknown error'}`);
      setTimeout(() => setEvaluationResult(null), 5000);
    }
  };

  return (
    <main className={styles.container}>
      <div className={styles.header}>
        <div className={styles.headerTop}>
          <button
            onClick={() => window.location.href = '/'}
            className={styles.backButton}
            title="Back to home"
          >
            ← Back
          </button>
          <h1>AIxcel - {sheet.charAt(0).toUpperCase() + sheet.slice(1)} Sheet</h1>
        </div>
        <div className={styles.toolbar}>
          <div className={styles.selectedCellInfo}>
            {primarySelection ? (
              <>
                <strong>{getColumnLabel(primarySelection.col)}{primarySelection.row + 1}</strong>
                {getCellValue(primarySelection.row, primarySelection.col) && (
                  <span className={styles.cellValuePreview}>
                    : {getCellValue(primarySelection.row, primarySelection.col).substring(0, 20)}
                    {getCellValue(primarySelection.row, primarySelection.col).length > 20 ? '...' : ''}
                  </span>
                )}
              </>
            ) : "No selection"}
          </div>

          {/* WebSocket connection status */}
          <div className={`${styles.connectionStatus} ${isConnected ? styles.connected : styles.disconnected}`}>
            <div className={styles.connectionDot}></div>
            {isConnected ? `Connected (${connectedUsers.length} users)` : 'Disconnected'}
          </div>

          <div className={styles.formulaBar}>
            <label>Formula:</label>
            <input
              type="text"
              placeholder="=SUM(A1:B5) or =AVERAGE(A1,B1,C1)"
              value={formula}
              onChange={(e) => setFormula(e.target.value)}
              onKeyDown={(e) => {
                if (e.key === 'Enter') {
                  evaluateFormula();
                }
              }}
              className={styles.formulaInput}
            />
            <button onClick={evaluateFormula} className={styles.evalButton}>
              Evaluate
            </button>
            {evaluationResult && (
              <div className={`${styles.evaluationResult} ${evaluationResult.startsWith('Error') ? styles.error : styles.success}`}>
                {evaluationResult}
              </div>
            )}
          </div>
          <div className={styles.formattingBar}>
            <button 
              onClick={() => applyFormatting('font_weight', 'bold')}
              className={`${styles.formatButton} ${currentFormatting.font_weight === 'bold' ? styles.active : ''}`}
            >
              <strong>B</strong>
            </button>
            <button 
              onClick={() => applyFormatting('font_style', 'italic')}
              className={`${styles.formatButton} ${currentFormatting.font_style === 'italic' ? styles.active : ''}`}
            >
              <em>I</em>
            </button>
            <input
              type="color"
              value={currentFormatting.background_color || '#ffffff'}
              onChange={(e) => applyFormatting('background_color', e.target.value)}
              className={styles.colorPicker}
              title="Cell Background Color"
            />
          </div>
        </div>
      </div>

      {/* Loading state */}
      {isLoading && (
        <div className={styles.loadingOverlay}>
          <div className={styles.loadingSpinner}></div>
          <p>Loading spreadsheet...</p>
        </div>
      )}

      {/* Error state */}
      {error && (
        <div className={styles.errorBanner}>
          <span>{error}</span>
          <button onClick={() => setError(null)} className={styles.closeButton}>×</button>
        </div>
      )}

      <div
        className={styles.spreadsheet}
        onScroll={(e) => {
          const target = e.target as HTMLElement;
          setScrollPosition({
            left: target.scrollLeft,
            top: target.scrollTop
          });
        }}
      >
        <div className={styles.gridContainer} style={{
          width: `${(visibleArea.endCol + 100) * COL_WIDTH + HEADER_WIDTH}px`,
          height: `${(visibleArea.endRow + 100) * ROW_HEIGHT + HEADER_HEIGHT}px`,
          position: 'relative'
        }}>
          {/* Column Headers */}
          <div className={styles.columnHeaders} style={{
            position: 'sticky',
            top: 0,
            left: 0,
            zIndex: 3,
            display: 'flex',
            backgroundColor: '#f0f0f0'
          }}>
            <div className={styles.cornerCell} style={{ 
              width: HEADER_WIDTH, 
              height: HEADER_HEIGHT,
              position: 'sticky',
              left: 0,
              zIndex: 4
            }}></div>
            {Array.from({ length: visibleArea.endCol - visibleArea.startCol + 10 }, (_, index) => {
              const col = visibleArea.startCol + index;
              return (
                <div 
                  key={col} 
                  className={styles.columnHeader} 
                  style={{ 
                    width: COL_WIDTH, 
                    height: HEADER_HEIGHT,
                    left: HEADER_WIDTH + col * COL_WIDTH
                  }}
                >
                  {getColumnLabel(col)}
                </div>
              );
            })}
          </div>

          {/* Row Headers and Cells */}
          {Array.from({ length: visibleArea.endRow - visibleArea.startRow + 10 }, (_, rowIndex) => {
            const row = visibleArea.startRow + rowIndex;
            return (
              <div key={row} className={styles.row} style={{
                position: 'absolute',
                top: HEADER_HEIGHT + row * ROW_HEIGHT,
                left: 0,
                width: '100%',
                height: ROW_HEIGHT,
                display: 'flex'
              }}>
                {/* Row Header */}
                <div 
                  className={styles.rowHeader} 
                  style={{ 
                    width: HEADER_WIDTH, 
                    height: ROW_HEIGHT,
                    position: 'sticky',
                    left: 0,
                    zIndex: 2
                  }}
                >
                  {row + 1}
                </div>
                
                {/* Cells */}
                {Array.from({ length: visibleArea.endCol - visibleArea.startCol + 10 }, (_, colIndex) => {
                  const col = visibleArea.startCol + colIndex;
                  const isSelected = isCellSelected(row, col);
                  const isPrimary = isPrimarySelection(row, col);
                  const bounds = getSelectionBounds();
                  const isBottomRight = isSelected && row === bounds.maxRow && col === bounds.maxCol;
                  
                  return (
                    <div
                      key={`${row}-${col}`}
                      className={`${styles.cell} ${
                        isSelected
                          ? isPrimary 
                            ? styles.primarySelectedCell 
                            : styles.selectedCell
                          : ""
                      }`}
                      style={{
                        width: COL_WIDTH,
                        height: ROW_HEIGHT,
                        position: 'absolute',
                        left: HEADER_WIDTH + col * COL_WIDTH,
                        fontWeight: getCellFormatting(row, col).font_weight || 'normal',
                        fontStyle: getCellFormatting(row, col).font_style || 'normal',
                        backgroundColor: getCellFormatting(row, col).background_color || 'white',
                        border: '1px solid #ddd',
                        boxSizing: 'border-box',
                      }}
                      onClick={(e) => handleCellClick(row, col, e)}
                      onMouseDown={(e) => handleCellMouseDown(row, col, e)}
                      onMouseOver={() => {
                        handleCellMouseOver(row, col);
                        if (isExtending) handleExtensionOver();
                      }}
                      onMouseUp={() => {
                        handleCellMouseUp();
                        if (isExtending) handleExtensionEnd(row, col);
                      }}
                      onDoubleClick={() => handleCellDoubleClick(row, col)}
                      onContextMenu={(e) => handleCellRightClick(e, row, col)}
                    >
                      {editingCell?.row === row && editingCell?.col === col ? (
                        <input
                          type="text"
                          value={editValue}
                          onChange={(e) => handleCellEdit(e.target.value)}
                          onBlur={handleCellSubmit}
                          onKeyDown={handleCellKeyDown}
                          className={styles.cellInput}
                          autoFocus
                        />
                      ) : (
                        <span>{getCellValue(row, col) || ""}</span>
                      )}
                      
                      {/* Extension handle (fill handle) */}
                      {isBottomRight && selectedCells.length > 0 && (
                        <div
                          className={styles.extensionHandle}
                          onMouseDown={handleExtensionStart}
                        />
                      )}
                    </div>
                  );
                })}
              </div>
            );
          })}
        </div>
      </div>

      {contextMenu && (
        <div 
          className={styles.contextMenu}
          style={{ top: contextMenu.y, left: contextMenu.x }}
        >
          <button onClick={copySelectedCells} className={styles.contextMenuItem}>
            Copy
          </button>
          <button onClick={clearSelectedCells} className={styles.contextMenuItem}>
            Clear Contents
          </button>
          <button onClick={() => clearSelection()} className={styles.contextMenuItem}>
            Clear Selection
          </button>
          <hr className={styles.contextMenuSeparator} />
          <button 
            onClick={() => applyFormatting('font_weight', 'bold')}
            className={styles.contextMenuItem}
          >
            Toggle Bold
          </button>
          <button 
            onClick={() => applyFormatting('font_style', 'italic')}
            className={styles.contextMenuItem}
          >
            Toggle Italic
          </button>
        </div>
      )}
    </main>
  );
}
