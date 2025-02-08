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
import { Tree, NodeApi, NodeRendererProps } from 'react-arborist';
import { RiArrowDownSLine } from "react-icons/ri";
import { RiArrowRightSLine } from "react-icons/ri";
import useResizeObserver from "use-resize-observer";
import "./filetree.scss";

/*
 TODO:
 - delete
 - styling
  - height
  - validation feedback not having own space
 - drag n drop but it will probably be hard so let do it later
*/

export type Path = string

type NodeData = {id: string, name: string, children: NodeData[], isRoot?: boolean}

export default function Filetree({api, project, onCreate = null, onMove = null, onDelete = null, onOpen = null}: {
    api: Api, 
    project: Project,
    onCreate?: (path: Path) => void, 
    onMove?: (from: Path, to: Path) => void,  
    onDelete?: (path : Path) => void,
    onOpen?: (path: Path) => void 
}) {

  function traverse(node: NodeData, proc: (_: NodeData) => void) {
    proc(node);
    node.children?.forEach(_ => traverse(_, proc));
  }

  function projectToTree(project : Project, files: ProjectFile[]) : NodeData[] {
    const rootName = `${project.owner_name} / ${project.name}`;
    const root = {id: "/", name: rootName, children: [] as any[], isRoot: true};
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

    // Put directories first for comfort
    traverse(root, _=> {
      _.children?.sort((a, b) => ((a.children != null) === (b.children != null))? 0 : (a.children != null)? -1 : 1);
    });

    return [root];
  }

  // Used as a cache to prevent having to re query the project at every file tree modification
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

  function onCreateInternal({parentNode, type, parentId}: {parentId: string, parentNode: NodeApi<any>, index: number, type: "internal" | "leaf"}) : Promise<{id: string}>  {    
    if (parentNode === null || parentNode.isRoot) // Not the same as isRoot from projectToTree
      parentId = "/";

    if (type === "leaf") {
      let name = "file";
      while (projectFiles.current.find(_ => _.path == `${parentId}${name}`))
        name = `new_${name}`;
      const path = `${parentId}${name}`;
      return api.create_file(project.id, path).then(response => {
        const file : ProjectFile = {id: response.id, path, content_uri: "", created_at: "", file_edited_at: "", author_name: "", editor_name: "", is_directory: false};
        projectFiles.current = [...projectFiles.current, file];
        const newTree = projectToTree(project, projectFiles.current);
        console.log(path)
        setTree(newTree);
        return {id: file.path};
      });  
    } else {
      let name = "directory";
      while (projectFiles.current.find(_ => _.path == `${parentId}${name}/`) != undefined)
        name = `new_${name}`;
      const path = `${parentId}${name}/`;

      return api.create_directory(project.id, path).then(response => {
        // Todo Full file response
        const file : ProjectFile = {id: response.id, path, content_uri: "", created_at: "", file_edited_at: "", author_name: "", editor_name: "", is_directory: true};
        projectFiles.current = [...projectFiles.current, file];
        const newTree = projectToTree(project, projectFiles.current);
        setTree(newTree);
        return {id: file.path};  
      });
    }
  }

  function FolderArrow({node}: {node: NodeApi<NodeData>}) {
    if (node.isLeaf) return <span></span>;
    return (<span>{node.isOpen ? <RiArrowRightSLine/> : <RiArrowDownSLine/>}</span>);
  }

  function Input({ node }: { node: NodeApi<NodeData> }) {
    const [editFeedback, setEditFeedback] = useState(null);

    return (
      <Form.Group className="mb-3">
        <Form.Control
          isInvalid={editFeedback != null}
          autoFocus
          type="text"
          defaultValue={node.data.name}
          onFocus={(e) => e.currentTarget.select()}
          onBlur={() => node.reset()}
          onKeyDown={(e) => {
            if (e.key === "Escape")
              node.reset();
            if (e.key === "Enter") {
              const file = projectFiles.current.find(_ => _.path == node.data.id);
              const name = e.currentTarget.value;
              const components = file.path.split('/');
              if (file.is_directory)
                components[components.length - 2] = name;
              else
                components[components.length - 1] = name;
              const path = components.join('/');

              api.move_file(project.id, file.id, path).then(_ => {
                node.submit(name);
              }).catch(error => {
                if (error.code == ErrorCode.BadParameter)
                  setEditFeedback(error.parameters[0].issue);
                else
                  setEditFeedback(error.message);
              });
            }
          }}
        />
        <Form.Control.Feedback type="invalid">
          {editFeedback}
        </Form.Control.Feedback>
      </Form.Group>
    );
  }

  function Node({node, tree, style, dragHandle}: NodeRendererProps<NodeData>) {
    const rootClassName = node.data.isRoot == true ? "root-item" : "";
    return (
      <div
        ref={dragHandle}
        style={style}
        onClick={() => node.isInternal && node.toggle()}
        className={rootClassName}
      >
        <FolderArrow node={node} />
        <span>{node.isEditing ? <Input node={node}/> : node.data.name}</span>
      </div>
    );
  }

  const { ref, width, height } = useResizeObserver();

  return (
    <div style={{height: "100%"}} ref={ref}>
      <Tree 
        height={height} 
        width={width}
        data={tree}
        onCreate={onCreateInternal}
        onRename={onEditInternal}
        disableEdit={_ => _.isRoot === true}
        disableDrag={_ => _.isRoot === true}
      >{Node}</Tree>
    </div>
  );
}