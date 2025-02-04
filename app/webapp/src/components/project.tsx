import Container from 'react-bootstrap/Container';
import Navbar from 'react-bootstrap/Navbar';
import Stack from 'react-bootstrap/Stack';
import { ChangeEvent, useState, KeyboardEvent, useEffect } from 'react';
import Form from 'react-bootstrap/Form';
import Accordion from 'react-bootstrap/Accordion';
import Button from 'react-bootstrap/Button';
import InputGroup from 'react-bootstrap/InputGroup';
import { Link } from "react-router";
import Spinner from 'react-bootstrap/Spinner';
import Navigation from "./navigation";
import ProjectExplorer from "./project_explorer";
import { ErrorCode, Api, Error, ParameterError } from "../api";
import { useParams } from "react-router";
import { Editor } from "prism-react-editor";
import { BasicSetup } from "prism-react-editor/setups";
import Filetree from "./filetree";
import "prism-react-editor/layout.css";
import "prism-react-editor/themes/github-light.css"

export default function Project({api} : {api: Api}) {

  const {projectId} = useParams();

  function onUpdate() {}

  return (
    <Stack style={{width: "100%"}}>
    <Navigation></Navigation>
    <hr style={{margin: 0}}/>
    <Stack direction="horizontal" style={{height: "100%", width: "100%"}}>
      <div style={{width: "17.5%", height: "100%"}}>
        <Filetree api={api}/>
      </div>
      <div className="vr" />

      <div style={{overflowY: "auto", height: "calc(100vh - 0.5in - 1px)", width: "calc(82.5% - 1px)", display: "inline-block"}}>
        <Editor language="jsx" value="const foo = 'bar'" onUpdate={onUpdate} >
          {(editor: any) => <BasicSetup editor={editor} />}
        </Editor>
      </div>
        

    </Stack>
  </Stack>
  );
}