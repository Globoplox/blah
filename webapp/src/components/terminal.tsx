import Container from 'react-bootstrap/Container';
import Navbar from 'react-bootstrap/Navbar';
import Stack from 'react-bootstrap/Stack';
import { ChangeEvent, useState, KeyboardEvent, useEffect, useRef } from 'react';
import Form from 'react-bootstrap/Form';
import Accordion from 'react-bootstrap/Accordion';
import Button from 'react-bootstrap/Button';
import InputGroup from 'react-bootstrap/InputGroup';
import { Link } from "react-router";
import Spinner from 'react-bootstrap/Spinner';
import Navigation from "./navigation";
import ProjectExplorer from "./project_explorer";
import { ErrorCode, Api, Error, ParameterError, Project, File as ProjectFile } from "../api";
import { useParams } from "react-router";
import { Editor, PrismEditor } from "prism-react-editor";
import { BasicSetup } from "prism-react-editor/setups";
import Filetree from "./filetree";
import { BrowserRouter, Routes, Route, useBeforeUnload } from "react-router";
import { useNavigate } from "react-router";
import { XTerm } from "@pablo-lion/xterm-react";
import { ITerminalOptions } from "@xterm/xterm";
import { AttachAddon } from '@xterm/addon-attach';
import CloseButton from 'react-bootstrap/CloseButton';
import "./terminal.scss";


export default function Terminal({socket, onClose}: {socket: WebSocket, onClose?: () => void}) {

  const theme = {
    background: '#F8F8F8',
    foreground: '#2D2E2C',
    selectionBackground: '#5DA5D533',
    selectionInactiveBackground: '#555555AA',
    cursorAccent: "#1E1E1D",
    cursor: "#1E1E1D",
    black: '#1E1E1D',
    brightBlack: '#262625',
    red: '#CE5C5C',
    brightRed: '#FF7272',
    green: '#5BCC5B',
    brightGreen: '#72FF72',
    yellow: '#d6af4b',
    brightYellow: '#f2b211',
    blue: '#5D5DD3',
    brightBlue: '#7279FF',
    magenta: '#BC5ED1',
    brightMagenta: '#E572FF',
    cyan: '#5DA5D5',
    brightCyan: '#72F0FF',
    white: '#F8F8F8',
    brightWhite: '#FFFFFF'
  };

  const baseOptions : ITerminalOptions = {
    convertEol: true,
    scrollback: 1000,
    cursorStyle: "block",
    cursorInactiveStyle: "underline",
    theme, 
    fontWeight: 400, 
    fontSize: 18, 
    fontFamily: "Consolas, Monaco, Andale Mono, Ubuntu Mono, monospace"
  };

  const [bigTerminal, setBigTerminal] = useState(false);
  const [options, setOptions] = useState({...baseOptions, rows: 15, cols: 80});
  const [key, setKey] = useState(socket.url + options.cols + options.rows);
  const [onKeyDown,setOnKeyDown] = useState(null);
  const termRef : React.MutableRefObject<XTerm> = useRef();

  useEffect(() => {
    setTimeout(() => {
      termRef.current?.focus();  
    }, 200); // It just works
  }, [key]);

  socket.onmessage = ((message: MessageEvent<any>) => {
    if (typeof(message.data) == "object") {
      const start = new TextDecoder("utf-8").decode(new Uint8Array(message.data.slice(0, 8)));
      if (start == "\x1B[?1049h") {
        setBigTerminal(true);
        setOptions({...baseOptions, rows: 40, cols: 170});
        setKey(socket.url + 40 + 170);
      } else if (start == "\x1B[?1049l") {
        setBigTerminal(false);
        setOptions({...baseOptions, rows: 15, cols: 80});
        setKey(socket.url + 15 + 80);
      }
    }
  });



  // key used to force recreation of the terminal, react might try to be smarter than it is otherwise 
  return <div style={{position: "relative"}} tabIndex={0} onKeyDown={onKeyDown} className={bigTerminal ? "modal-terminal" : ""}>
    <XTerm ref={termRef} key={key} options={options} addons={[new AttachAddon(socket, {bidirectional: true})]} />
    <CloseButton aria-label="Close terminal" style={{position: "absolute", top: bigTerminal ? "4%" : "16px", right: bigTerminal ? "2%" : "16px"}} onClick={() => onClose?.()}/>
  </div>;
}
