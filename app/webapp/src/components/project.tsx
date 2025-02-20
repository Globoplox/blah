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
import { ErrorCode, Api, Error, ParameterError, Project, File as ProjectFile, ProjectNotification } from "../api";
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
  
  const [project, setProject] = useState(null as Project);
  const [file, setFile] = useState(null as {content: string, type: string, path: string});
  const currentEditedFilePathRef = useRef(null);

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
 
  // Save the document when dirty and mouse leave the document
  useEffect(() => {
    function onMayLeavePage() {
      if (syncTimeoutId.current != null) {
        clearTimeout(syncTimeoutId.current);
        syncTimeoutId.current = null;
        api.update_file(project.id, file.path, editorContent.current);
      }
    }
    document.body.addEventListener("mouseleave", onMayLeavePage);

    // Cleanup
    return () => document.body.removeEventListener("mouseleave", onMayLeavePage);
  }, [project, file]);


  function doLoadProject() { 
    api.read_project(projectId).then(project => {
      setProject(project);
    }).catch(error => {
      if (error.code === ErrorCode.Unauthorized)
        navigate(`/login?redirectTo=${location.pathname}`);
    });
  }

  function doLoadFile() {
    if (project != null && filePath != null) {
      const fileToOpen = project.files?.find(_ => _.path == filePath)

      if (fileToOpen != null && !fileToOpen.is_directory) {
        const type = fileType(fileToOpen);
        fetch(fileToOpen.content_uri).then(_ => _.text().then(text => {
          editorContent.current = text;
          currentEditedFilePathRef.current = fileToOpen.path;
          setFile({path: fileToOpen.path, content: text, type});
        }));
      } else {
        navigate(`/project/${projectId}`);
      }
    } else {
      setFile(null);
      currentEditedFilePathRef.current = null;
    }
  }

  function onFileTreeMove(oldPath: string, file: ProjectFile) {
    const index = project.files?.findIndex(_ => _.path == oldPath);
    if (index != -1) {
      project.files[index] = file;
    }
  }

  // Close currently edited file from editor if it has been deleted 
  function onFileTreeDelete(deletedFilePath: string) {
    if (deletedFilePath == currentEditedFilePathRef.current) {
      if (syncTimeoutId.current)
        clearTimeout(syncTimeoutId.current);
      syncTimeoutId.current = null;
      editorContent.current = "";
      setFile(null);
      navigate(`/project/${projectId}`);
    }
  }

  // Add created file to current cache so we can open it because we have it's content_uri
  function onFileTreeCreate(file: ProjectFile) {
    const existing = project.files?.find(_ => _.path == file.path);
    // Edit project in place, no need to re-render
    if (existing == null || existing == undefined) {
      project.files = [...project.files, file];
    }
  }

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
    if (file != null && fileToOpen.path == file.path)
      return;
   
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
    const fileToRun = project.files?.find(_ => _.path == filePath);
    (socket?.socket as WebSocket)?.close();
    setSocket({key: Date.now(), socket: api.run_file(project.id, fileToRun.path)});
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

  function onTerminalClose() {
    socket?.socket?.close();
    setSocket(null);
  }

  return (
    <Stack style={{width: "100%"}}>
    <Navigation api={api} project={project}></Navigation>
    <hr style={{margin: 0}}/>
    <Stack direction="horizontal" style={{height: "100%", width: "100%"}}>

      <div style={{width: "17.5%", height: "calc(100vh - 0.5in - 1px)"}}>
        {
          project != null
          ? <Filetree api={api} project={JSON.parse(JSON.stringify(project))} onDelete={onFileTreeDelete} onOpen={onFileTreeOpen} onCreate={onFileTreeCreate} onMove={onFileTreeMove} onRun={onRunFile}/>
          : <div className="d-flex align-items-center mt-3" style={{width: "100%"}}>
              <Spinner size="sm" className="ms-auto"/>
              <strong className="ms-2 me-auto">Loading...</strong>
            </div>
        }
      </div>

      <div className="vr" />

      <Stack direction="vertical" style={{height: "calc(100vh - 0.5in - 1px)"}}>

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
            <Terminal key={socket.key} socket={socket.socket} onClose={onTerminalClose}/>
          </div> : 
          <></>
        }


      </Stack>
    </Stack>
  </Stack>
  );
}