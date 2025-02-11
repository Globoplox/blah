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
import "prism-react-editor/prism/languages/ini";
import "prism-react-editor/prism/languages/clike";
import "prism-react-editor/prism/languages/json";
import "./prism_language_blah";
import "./prism_language_stacklang";
import "prism-react-editor/layout.css";
import "prism-react-editor/themes/github-light.css"

import Terminal from "./terminal";

export default function Project({api} : {api: Api}) {
  const navigate = useNavigate();

  const params = useParams();
  const projectId = params["projectId"];
  let filePath = params["*"];

  if (filePath == undefined)
    filePath = null;
  else
    filePath = `/${filePath}`;

  console.log("PARAMS", params);
  
  const [project, setProject] = useState(null as Project);
  const [file, setFile] = useState(null as {content: string, type: string, path: string});

  // Editor content. The deitor is NOT controlled, so this is a ref.
  const editorContent = useRef("");

  // ID of the timeout to persist the document changes.
  // It is null when the document is not dirty.
  const syncTimeoutId = useRef(null);
  
  // When the project change, load the project
  const loadProject = useEffect(() => doLoadProject(), [projectId]);
  // When the project file change, or a project is loaded, load the file
  const loadFile = useEffect(() => doLoadFile(), [project, filePath]);
  // Terminal job socket
  const [socket, setSocket] = useState(null);

  // Save the document when dirty and mouse leav the document
  useEffect(() => {
    function onMayLeavePage() {
      if (syncTimeoutId.current != null) {
        clearTimeout(syncTimeoutId.current);
        syncTimeoutId.current = null;
        api.update_file(project.id, file.path, editorContent.current);
      }
    }
    document.body.addEventListener("mouseleave", onMayLeavePage);
    return () => document.body.removeEventListener("mouseleave", onMayLeavePage);
  }, [project, file]);

  function doLoadProject() {
    api.read_project(projectId).then(project => {
      setProject(project);
    });
  }

  function doLoadFile() {
    console.log("ON DO LOAD FILE", project, filePath)

    if (project != null && filePath != null) {
      const fileToOpen = project.files?.find(_ => _.path == filePath)
      console.log("FOUND FILE", fileToOpen)

      if (fileToOpen != null && !fileToOpen.is_directory) {
        const type = fileType(fileToOpen);
        fetch(fileToOpen.content_uri).then(_ => _.text().then(text => {
          editorContent.current = text;
          setFile({path: fileToOpen.path, content: text, type});
        }));
      } else {
        navigate(`/project/${projectId}`);
      }
    }
  }

  function onFileTreeDelete(filePath: string) {
    if (filePath === file?.path) {
      if (syncTimeoutId.current)
        clearTimeout(syncTimeoutId.current);
      syncTimeoutId.current = null;
      editorContent.current = "";
      setFile(null);
    }
  }

  // TODO: onFileTree move, to refresh

  function fileType(file : ProjectFile) : string {
    if (file.path.endsWith(".sl"))
      return "stacklang";
    else if (file.path.endsWith(".blah"))
      return "blah";
    else if (file.path.endsWith(".ini"))
      return "ini";
    else if (file.path.endsWith(".recipe") || file.path.endsWith(".json"))
      return "json";
    return "txt";
  }
  
  function onFileTreeOpen(fileToOpen: ProjectFile) {
    console.log("ON FILE OPEN", file, fileToOpen)
    if (file != null && fileToOpen.path == file.path)
      return;
   
    const type = fileType(fileToOpen);

    if (syncTimeoutId.current != null) {
      clearTimeout(syncTimeoutId.current);
      syncTimeoutId.current = null;
      api.update_file(project.id, file.path, editorContent.current);
    }

    navigate(`/project/${projectId}/file${fileToOpen.path}`);
  }

  function onUpdate(value: string, editor: PrismEditor) {
    if (value == editorContent.current)
      return;
    editorContent.current = value;

    if (syncTimeoutId.current == null) {
      syncTimeoutId.current = setTimeout(() => {
        api.update_file(project.id, file.path, editorContent.current);
        syncTimeoutId.current = null;
      }, 5000);
    }
  }


  function onRunFile(filePath : string) {
    // Flush
    if (syncTimeoutId.current != null) {
      clearTimeout(syncTimeoutId.current);
      syncTimeoutId.current = null;
      api.update_file(project.id, file.path, editorContent.current);
    }
    // Open socket
    const fileToRun = project.files?.find(_ => _.path == filePath)
    api.run_file(project.id, fileToRun.path, (newSocket: WebSocket) => {
      (socket as WebSocket)?.close();
      newSocket.onopen = () => {
        console.log("SET NEW SOCKET");
        setSocket(newSocket)
      };
    });
  }

  function NoFileOpened() {
    return <Container className="flex-flex" style={{height: "100%"}}>
      <div className="flex-flex center-center" >
        <div>
        <h4>No file opened</h4>
        <br/>
        <p>
          Select a file on the explorer to start editing.
        </p>
        <ul>
          <li>Create a file: A</li>
          <li>Create a directory: Ctrl+A</li>
          <li>Delete a file or directory: Return</li>
          <li>Rename a file or directory: Enter</li>
        </ul>
        </div>
      </div>
    </Container>;
  }

  return (
    <Stack style={{width: "100%"}}>
    <Navigation></Navigation>
    <hr style={{margin: 0}}/>
    <Stack direction="horizontal" style={{height: "100%", width: "100%"}}>

      <div style={{width: "17.5%", height: "calc(100vh - 0.5in - 1px)"}}>
        {
          project != null
          ? <Filetree api={api} project={project} onDelete={onFileTreeDelete} onOpen={onFileTreeOpen}/>
          : <div className="d-flex align-items-center mt-3" style={{width: "100%"}}>
              <Spinner size="sm" className="ms-auto"/>
              <strong className="ms-2 me-auto">Loading...</strong>
            </div>
        }
      </div>

      <div className="vr" />

      <Stack direction="vertical" style={{height: "calc(100vh - 0.5in - 1px)"}}>
        {
          (file != null && file.type == "json") ?
          <Button style={{position: "absolute", top: 0, right: 0}} onClick={() => onRunFile(file.path)}>Run</Button> :
          <></>
        }

        {
          file != null ?
          <Editor language={file.type} value={file.content} onUpdate={onUpdate} >
            {(editor: any) => <BasicSetup editor={editor}/>}
          </Editor> :
          (project != null ? <NoFileOpened/> : <></>)
        }
  
        { 
          socket != null ? 
          <div className="mt-auto">
            <hr style={{margin: 0}}/>
            <Terminal socket={socket}/>
          </div> : 
          <></>
        }


      </Stack>
    </Stack>
  </Stack>
  );
}