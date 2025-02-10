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
import { AttachAddon } from '@xterm/addon-attach';
import "./terminal.scss";

export default function Terminal({socket}: {socket: WebSocket}) {

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
    yellow: '#CCCC5B',
    brightYellow: '#FFFF72',
    blue: '#5D5DD3',
    brightBlue: '#7279FF',
    magenta: '#BC5ED1',
    brightMagenta: '#E572FF',
    cyan: '#5DA5D5',
    brightCyan: '#72F0FF',
    white: '#F8F8F8',
    brightWhite: '#FFFFFF'
  };

  const ref = useRef(null);

  // key used to force recreation of the terminal, react might try to be smarter than it is otherwise 
  return <XTerm ref={ref} key={socket.url} options={{
    convertEol: true,
    scrollback: 1000,
    rows: 15,
    cursorStyle: "block",
    cursorInactiveStyle: "underline",
    theme, 
    fontWeight: 400, 
    fontSize: 18, 
    fontFamily: "Consolas, Monaco, Andale Mono, Ubuntu Mono, monospace"
  }} addons={[new AttachAddon(socket, {bidirectional: true})]} />;
}