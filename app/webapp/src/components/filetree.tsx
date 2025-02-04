import Container from 'react-bootstrap/Container';
import Navbar from 'react-bootstrap/Navbar';
import Stack from 'react-bootstrap/Stack';
import { ChangeEvent, useState, useEffect, FocusEvent, KeyboardEvent, useRef } from 'react';
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
import React, {MouseEvent, FormEvent} from "react";
import TreeView, { flattenTree } from "react-accessible-treeview";
import { DiCss3, DiJavascript, DiNpm } from "react-icons/di";
import { FaList, FaRegFolder, FaRegFolderOpen } from "react-icons/fa";
import { TfiPlus } from "react-icons/tfi";
import "./filetree.scss";

type Path = string

/*
    transform a list of path into:
    { id, name, parent, children, isBranch, metadata: {path} }
    and an incremental id

    // Button to add file, but how to add dir ? Need two buttons (or use a context menu)

    // also need buttons to add files/dir on root ? 
    // Maybe:

    project name    +
    O aaa
    X bbb           +
      X ccc
      O ddd

    make the root explicit as the project name ? and make it uneditable.

*/

export default function Filetree({api, onCreate = null, onMove = null, onDelete = null, onOpen = null} : {
    api: Api, 
    onCreate?: (path: Path) => void, 
    onMove?: (from: Path, to: Path) => void,  
    onDelete?: (path : Path) => void,
    onOpen?: (path: Path) => void 
}) {
  
  const folder = {
    name: "",
    children: [
      {
        name: "src",
        children: [{ name: "index.js" }, { name: "styles.css" }],
      },
      {
        name: "node_modules",
        children: [
          {
            name: "react-accessible-treeviewwwwwwwwwwwwwww",
            children: [{ name: "bundle.js" }],
          },
          { name: "react", children: [{ name: "bundle.js" }] },
        ],
      },
      {
        name: ".npmignore",
      },
      {
        name: "package.json",
      },
      {
        name: "webpack.config.js",
      },
    ],
  };

  const [data, setData] = useState(flattenTree(folder));

  // The id (as in the flattened tree data entries id)
  // of the element whose name is currently being edited (if any)
  // {id: string, value: string, source: "renaming" | "creating"}
  const [editedName, setEditedName] = useState(null);

  function addFileToDirectory(directory : any) {
    return (e: MouseEvent<SVGElement>) => {
      e.preventDefault();
      e.stopPropagation();
      const newId = 999; // SHOULD BE THE NEXT AVAILABLE ID
      data.push({name: "", id: newId, parent: directory.id, children: []});
      directory.children.push(newId);
      console.log(data);
      setData(JSON.parse(JSON.stringify(data)));
      setEditedName({id: newId, value: ""});
      return false;
    };
  }

  function FolderIcon({isOpen}: {isOpen : boolean}) {
    return isOpen ? (
      <FaRegFolderOpen color="e8a87c" className="icon" />
    ) : (
      <FaRegFolder color="e8a87c" className="icon" />
    );
  }

  function FileIcon({filename} : {filename: string}) {
    const extension = filename.slice(filename.lastIndexOf(".") + 1);
    switch (extension) {
      case "js":
        return <DiJavascript color="black" className="icon" />;
      case "css":
        return <DiCss3 color="black" className="icon" />;
      case "json":
        return <FaList color="black" className="icon" />;
      case "npmignore":
        return <DiNpm color="black" className="icon" />;
      default:
        return null;
    }
  };

  function onRenamingChange(event : ChangeEvent<HTMLInputElement>) {
    console.log("asasasasassa");
    data.find(_ => _.id == editedName?.id).name = event.target.value;

    if (editedName?.previous !== null) {
      // on move fullpath, previous fullpath, value fullpath

    } else {
      // oncreate fullpath
    }

    console.log(data);
    setData(JSON.parse(JSON.stringify(data)));
    setEditedName({id: editedName.id, value: event.target.value, previous: editedName.previous});
    event.preventDefault();
    event.stopPropagation();
  }

  function onRenamingFinished(event : KeyboardEvent<HTMLInputElement>) {
    if (event.key === 'Enter') {
      setEditedName(null);
      event.preventDefault();
    }
    event.stopPropagation();  
  }

  function renderer({
    element, isBranch, isExpanded, getNodeProps, level}: {
      element: any, 
      isBranch: boolean, 
      isExpanded: boolean,
      getNodeProps: () => any,
      level: number
  }) {
    return (
      <div {...getNodeProps()} style={{ paddingLeft: 20 * level, whiteSpace: "nowrap", width: '100%'}}>
        <Stack direction="horizontal">
          {isBranch ? (
            <FolderIcon isOpen={isExpanded} />
          ) : (
            <FileIcon filename={element.name} />
          )}

          {
            (editedName != null && editedName.id == element.id) ? (
              <Form.Control autoFocus size="sm" type="text" value={editedName.value} onKeyDown={onRenamingFinished} onChange={onRenamingChange} />
            ) : (
              <div>{element.name}</div>
            )
          }

          {isBranch ? (
            <TfiPlus className="create-file-button ms-auto" onClick={addFileToDirectory(element)} />
          ) : null}
        </Stack>
      </div>
    );
  };



  return (
    <div className="directory mt-2">
      {JSON.stringify(editedName)}
      <TreeView
        data={data}
        nodeRenderer={renderer}
      />
    </div>
  );
}