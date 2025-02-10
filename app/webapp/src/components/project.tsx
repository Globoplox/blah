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

  const {projectId, fileId} = useParams();
  const [isLoaded, setIsLoaded] = useState(false);
  const [project, setProject] = useState(null as Project);
  const [file, setFile] = useState(null as {content: string, type: string, id: string});
  const editorContent = useRef("");
  const syncTimeoutId = useRef(null);
  const loadProjects = useEffect(() => load(), [projectId, fileId]);
  
  useEffect(() => {
    function onMayLeavePage() {
      if (syncTimeoutId.current != null) {
        clearTimeout(syncTimeoutId.current);
        syncTimeoutId.current = null;
        api.update_file(project.id, file.id, editorContent.current);
      }
    }
    document.body.addEventListener("mouseleave", onMayLeavePage);
    return () => document.body.removeEventListener("mouseleave", onMayLeavePage);
  }, [project, file]);

  function load() {
    api.read_project(projectId).then(project => {
      setIsLoaded(true);
      setProject(project);
      if (fileId != null) {
        const fileToOpen = project.files?.find(_ => _.id == fileId)
        if (fileToOpen != null && !fileToOpen.is_directory) {
          const type = fileType(fileToOpen);
          fetch(fileToOpen.content_uri).then(_ => _.text().then(text => {
            editorContent.current = text;
            setFile({id: fileToOpen.id, content: text, type});
          }));
        } else {
          navigate(`/project/${projectId}`);
        }
      }
    });
  }

  function onFileTreeDelete(fileId: string) {
    if (fileId === file?.id) {
      if (syncTimeoutId.current)
        clearTimeout(syncTimeoutId.current);
      syncTimeoutId.current = null;
      editorContent.current = "";
      setFile(null);
    }
  }

  function fileType(file : ProjectFile) : string {
    if (file.path.endsWith(".sl"))
      return "stacklang";
    else if (file.path.endsWith(".blah"))
      return "blah";
    else if (file.path.endsWith(".ini"))
      return "ini";
    else if (file.path.endsWith(".recipe"))
      return "json";
    return "txt";
  }
  
  function onFileTreeOpen(fileToOpen: ProjectFile) {
    if (file != null && fileToOpen.id == file.id)
      return;
   
    const type = fileType(fileToOpen);

    if (syncTimeoutId.current != null) {
      clearTimeout(syncTimeoutId.current);
      syncTimeoutId.current = null;
      api.update_file(project.id, file.id, editorContent.current);
    }

    navigate(`/project/${projectId}/file/${fileToOpen.id}`);
  }

  function onUpdate(value: string, editor: PrismEditor) {
    if (value == editorContent.current)
      return;
    editorContent.current = value;

    if (syncTimeoutId.current == null) {
      syncTimeoutId.current = setTimeout(() => {
        api.update_file(project.id, file.id, editorContent.current);
        syncTimeoutId.current = null;
      }, 5000);
    }
  }

  const [socket, setSocket] = useState(null);

  function onRunFile(fileId : string) {
    // Flush
    if (syncTimeoutId.current != null) {
      clearTimeout(syncTimeoutId.current);
      syncTimeoutId.current = null;
      api.update_file(project.id, file.id, editorContent.current);
    }
    // Open socket
    const fileToRun = project.files?.find(_ => _.id == fileId)
    api.run_file(project.id, fileToRun.path, (newSocket: WebSocket) => {
      (socket as WebSocket)?.close();
      newSocket.onopen = () => setSocket(newSocket);
    });
  }

  function NoFileOpened() {
    return <Container className="flex-flex" style={{height: "100%"}}>
      <div className="flex-flex center-center" >
        <h4>No file opened</h4>
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
    </Container>;
  }

  return (
    <Stack style={{width: "100%"}}>
    <Navigation></Navigation>
    <hr style={{margin: 0}}/>
    <Stack direction="horizontal" style={{height: "100%", width: "100%"}}>

      <div style={{width: "17.5%", height: "calc(100vh - 0.5in - 1px)"}}>
        {
          isLoaded
          ? <Filetree api={api} project={project} onDelete={onFileTreeDelete} onOpen={onFileTreeOpen}/>
          : <div className="d-flex align-items-center mt-3" style={{width: "100%"}}>
              <Spinner size="sm" className="ms-auto"/>
              <strong className="ms-2 me-auto">Loading...</strong>
            </div>
        }
      </div>

      <div className="vr" />

      <Stack direction="vertical">
        {
          (file != null && file.type == "json") ?
          <Button style={{position: "absolute", top: 0, right: 0}} onClick={() => onRunFile(file.id)}>Run</Button> :
          <></>
        }

        <div style={{overflowY: "auto", height: "calc(100vh - 0.5in - 1px)", display: "inline-block"}}>
          {
            file != null ?
            <Editor language={file.type} value={file.content} onUpdate={onUpdate} >
              {(editor: any) => <BasicSetup editor={editor}/>}
            </Editor> :
            <NoFileOpened/>
          }
    
          { socket ? <Terminal socket={socket}/> : <></>}
        </div>


      </Stack>


    </Stack>
  </Stack>
  );
}