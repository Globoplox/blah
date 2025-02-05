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
import { ErrorCode, Api, Error, ParameterError, Project } from "../api";
import { useParams } from "react-router";
import React, {MouseEvent, FormEvent} from "react";
import TreeView, { flattenTree } from "react-accessible-treeview";
import { DiCss3, DiJavascript, DiNpm } from "react-icons/di";
import { FaList, FaRegFolder, FaRegFolderOpen } from "react-icons/fa";
import { TfiPlus } from "react-icons/tfi";
import "./filetree.scss";




// TODO: redo it all with https://github.com/brimdata/react-arborist which suport the features we want natively


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

export default function Filetree({api, project, onCreate = null, onMove = null, onDelete = null, onOpen = null} : {
    api: Api, 
    project: Project,
    onCreate?: (path: Path) => void, 
    onMove?: (from: Path, to: Path) => void,  
    onDelete?: (path : Path) => void,
    onOpen?: (path: Path) => void 
}) {
  

  function projectToTreedata(id: number, project : Project) : {id: number, treedata: any[], expandedIds: number[]} {
    const treedata : any[] = []; // Flat array of all nodes
    const nodes : Record<string, any> = {}; // Hashmap of directory nodes indexed by full path
    const fakeRoot = { id: (id += 1), name: "", parent: null as number, isBranch: true, children: [] as number[], metadata: {} };
    const expandedIds : number[] = []; 
    treedata.push(fakeRoot);

    const rootNode = { id: (id += 1), name: `${project.owner_name} / ${project.name}`, parent: fakeRoot.id, isBranch: true, children: [] as number[], metadata: {isRoot: true} };
    fakeRoot.children.push(rootNode.id);
    treedata.push(rootNode);
    expandedIds.push(rootNode.id);

    let test = { id: (id += 1), name: "tst", parent: rootNode.id, isBranch: true, children: [] as number[], metadata: {} };
    treedata.push(test);
    rootNode.children.push(test.id);


    project.files?.forEach(file => {
      let parent = rootNode;
      const path = file.path.split('/');
      const basename = path[path.length - 1];
      const directories = path.slice(0, -1);
      let dirIndex = 0;
      while (dirIndex < directories.length) {
        const fullDirectoryPath = directories.slice(0, dirIndex + 1).join('/');
        let current = nodes[fullDirectoryPath];
        if (current == null) {
          current = { id: (id += 1), name: directories[dirIndex], parent:parent.id, isBranch: true, children: [] as number[], metadata: {} };
          nodes[fullDirectoryPath] = current;
          treedata.push(current);
        }
        parent = current;
        dirIndex += 1;
      }
      const node = { id: (id += 1), name: basename, parent: parent.id, isBranch: false, children: [] as number[], metadata: {} };
      parent.children.push(node.id);
      treedata.push(node);
    });

    return {id, treedata, expandedIds};
  }

  const nodesIncrementalId = useRef(0);
  const [data, setData] = useState(() => {
    const {id, treedata, expandedIds} = projectToTreedata(nodesIncrementalId.current, project);
    nodesIncrementalId.current = id;
    return {treedata, expandedIds};
  });

  console.log(data);

  // The id (as in the flattened tree data entries id)
  // of the element whose name is currently being edited (if any)
  // {id: string, value: string, source: "renaming" | "creating"}
  const [editedName, setEditedName] = useState(null);

  // Used to force focus
  const editedInput = useRef(null);
  console.log(editedInput.current);

  function addFileToDirectory(directory : any) {
    return (e: MouseEvent<SVGElement>) => {
      e.preventDefault();
      e.stopPropagation();
      e.nativeEvent.stopPropagation();
      e.nativeEvent.preventDefault();
      e.nativeEvent.stopImmediatePropagation();

      if (editedName != null) {
        const previouEditNodeIndex = data.treedata.findIndex(_ => _.id == editedName?.id);
        const previouEditNode = data.treedata[previouEditNodeIndex];
        const previousEditNodeParent = data.treedata.find(_ => _.id == previouEditNode.parent);
        previousEditNodeParent.children.splice(previousEditNodeParent.children.indexOf(previouEditNode.id), 1);
        data.treedata.splice(previouEditNodeIndex, 1);
      }

      const newId = (nodesIncrementalId.current += 1);
      data.treedata.push({name: "", id: newId, parent: directory.id, children: []});
      directory.children.push(newId);
      data.expandedIds.push(directory.id);
      console.log(data);
      setData(JSON.parse(JSON.stringify(data)));
      setEditedName({id: newId, value: ""});
      return true;
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
    data.treedata.find(_ => _.id == editedName?.id).name = event.target.value;

    if (editedName?.previous !== null) {
      // on move fullpath, previous fullpath, value fullpath

    } else {
      // oncreate fullpath
    }

    setData(data);
    setEditedName({id: editedName.id, value: event.target.value, previous: editedName.previous});
    event.preventDefault();
    event.stopPropagation();
  }

  function onRenamingFinished(event : KeyboardEvent<HTMLInputElement>) {
    if (event.key === 'Enter') {
      // if value is empty, remove the input element 
      if ((event.nativeEvent.target as HTMLInputElement).value == "") {
        const previouEditNodeIndex = data.treedata.findIndex(_ => _.id == editedName?.id);
        const previouEditNode = data.treedata[previouEditNodeIndex];
        const previousEditNodeParent = data.treedata.find(_ => _.id == previouEditNode.parent);
        previousEditNodeParent.children.splice(previousEditNodeParent.children.indexOf(previouEditNode.id), 1);
        data.treedata.splice(previouEditNodeIndex, 1);
        setData(JSON.parse(JSON.stringify(data)));
      }

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
      <div {...getNodeProps()} style={{ paddingLeft: 20 *(element.metadata?.isRoot ? level : level - 1), whiteSpace: "nowrap", width: '100%'}}>
        <Stack direction="horizontal">
        
          {
            isBranch ? (
              !element.metadata?.isRoot ? <FolderIcon isOpen={isExpanded} /> : null
            ) : (
              <FileIcon filename={element.name} />
            )
          }

          {
            (editedName != null && editedName.id == element.id) ? (
              <Form.Control ref={editedInput} autoFocus size="sm" type="text" value={editedName.value} onKeyDown={onRenamingFinished} onChange={onRenamingChange} />
            ) : (
              (isBranch && element.metadata?.isRoot) ?
              <strong>{element.name}</strong> :
              <div>{element.name}</div> 
            )
          }

          {
            isBranch ? (
              <TfiPlus className="create-file-button ms-auto" onClick={addFileToDirectory(element)} />
            ) : null
          }

        </Stack>
      </div>
    );
  };



  return (
    <div className="directory mt-2">
      <TreeView
        data={data.treedata}
        expandedIds={data.expandedIds}
        nodeRenderer={renderer}
      />
    </div>
  );
}