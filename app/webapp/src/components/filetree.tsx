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
import { ErrorCode, Api, Error, ParameterError, Project, File as ProjectFile } from "../api";
import { useParams } from "react-router";
import React, {MouseEvent, FormEvent} from "react";
import { DiCss3, DiJavascript, DiNpm } from "react-icons/di";
import { FaList, FaRegFolder, FaRegFolderOpen } from "react-icons/fa";
import { TfiPlus } from "react-icons/tfi";
import { Tree, NodeApi } from 'react-arborist';
import "./filetree.scss";

export type Path = string

export default function Filetree({api, project, onCreate = null, onMove = null, onDelete = null, onOpen = null}: {
    api: Api, 
    project: Project,
    onCreate?: (path: Path) => void, 
    onMove?: (from: Path, to: Path) => void,  
    onDelete?: (path : Path) => void,
    onOpen?: (path: Path) => void 
}) {

  function projectToTree(project : Project, files: ProjectFile[]) : any[] {
    const rootName = `${project.owner_name} / ${project.name}`;
    const root = {id: "/", name: rootName, children: [] as any[]};
    const hash : Record<string, any> = {}; // Hashmap of directory nodes indexed by full path
    hash["/"] = root;

    const sorted = files.sort((a, b) =>
      (a.path.length - b.path.length) || (a.path.localeCompare(b.path))
    );

    sorted.forEach(file => {

      if (file.is_directory) {
        const components = file.path.split('/');
        const base = components.slice(0, components.length - 2).join('/');
        const node = {id: file.path, name: `${components[components.length - 2]}`, children: [] as any[]};
        hash[`${base}/`].children.push(node);
        hash[node.id] = node;
      } else {
        const components = file.path.split('/');
        const base = components.slice(0, components.length - 1).join('/');
        const node = {id: file.path, name: components[components.length - 1]};
        hash[`${base}/`].children.push(node);
        hash[node.id] = node;  
      }
    });


    return [root];
  }

  // Used as a cache to prevent having to rquery the project at every file tree modification
  const projectFiles = useRef(project.files);
  const [tree, setTree] = useState(projectToTree(project, projectFiles.current));

  function onEditInternal({id, name, node} : {id: string, name: string, node: NodeApi<any>}) {
    const file = projectFiles.current.find(_ => _.path == id);
    const components = file.path.split('/');
    if (file.is_directory)
      components[components.length - 2] = name;
    else
      components[components.length - 1] = name;
    file.path = components.join('/');
    const newTree = projectToTree(project, projectFiles.current);
    setTree(newTree);
  }

  // Can return a promise !
  function onCreateInternal({parentNode, type, parentId}: {parentId: string, parentNode: NodeApi<any>, index: number, type: "internal" | "leaf"}) : {id: string}  {    
    if (parentNode === null || parentNode.isRoot) // Not the same as isRoot from projectToTree
      parentId = "/";

    if (type === "leaf") {
      let name = "file";
      while (projectFiles.current.find(_ => _.path == `${parentId}${name}`))
        name = `new_${name}`;
      const file : ProjectFile = {id: "stuff", path: `${parentId}${name}`, content_uri: "", created_at: "", file_edited_at: "", author_name: "", editor_name: "", is_directory: false};
      // API request, along or instead of the projectFiles ref
      projectFiles.current = [...projectFiles.current, file];
      const newTree = projectToTree(project, projectFiles.current);
      setTree(newTree);
      return {id: file.path};
    } else {
      let name = "directory";
      while (projectFiles.current.find(_ => _.path == `${parentId}${name}/`) != undefined)
        name = `new_${name}`;
      const file : ProjectFile = {id: "stuff", path: `${parentId}${name}/`, content_uri: "", created_at: "", file_edited_at: "", author_name: "", editor_name: "", is_directory: true};
      // API request, along or instead of the projectFiles ref
      projectFiles.current = [...projectFiles.current, file];
      const newTree = projectToTree(project, projectFiles.current);
      setTree(newTree);
      return {id: file.path};
    }
  }

  return (
    <div className="directory mt-2">
      <Tree 
        data={tree}
        onCreate={onCreateInternal}
        onRename={onEditInternal}
        disableEdit={_ => _.isRoot === true}
        disableDrag={_ => _.isRoot === true}
      />;
    </div>
  );
}