import { useState, useRef, useEffect } from 'react';
import Form from 'react-bootstrap/Form';
import { ErrorCode, Api, Project, File as ProjectFile, ProjectNotification } from "../api";
import { Tree, NodeApi, NodeRendererProps } from 'react-arborist';
import { RiArrowDownSLine } from "react-icons/ri";
import { RiArrowRightSLine } from "react-icons/ri";
import useResizeObserver from "use-resize-observer";
import Toast from 'react-bootstrap/Toast';
import ToastContainer from 'react-bootstrap/ToastContainer';
import Stack from 'react-bootstrap/Stack';
import { FaRegFile } from "react-icons/fa";
import { FaRegFolder } from "react-icons/fa";
import { GrPlay } from "react-icons/gr";

import "./filetree.scss";

type NodeData = {id: string, name: string, children: NodeData[], isRoot?: boolean}
type Toast = {id: number, body: string}

export default function Filetree({api, project, onOpen = null, onDelete = null, onCreate = null, onMove = null, onRun = null}: {
    api: Api, 
    project: Project,
    onOpen?: (file: ProjectFile) => void,
    onCreate?: (file: ProjectFile) => void,
    onMove?: (oldPath: string, file: ProjectFile) => void,
    onDelete?: (id: string) => void,  
    onRun?: (id: string) => void
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
  const [toasts, setToasts] = useState([] as Toast[]);
  const toastId = useRef(0);

  // Open notification socket
  const notifications = useRef(null);
  useEffect(() => {
    notifications.current?.close();
    notifications.current = null;
    api.register_notification(project.id, (socket) => {
      notifications.current = socket;
      socket.onmessage = (ev) => {
        const notification = JSON.parse(ev.data) as ProjectNotification;
        
        if (notification.event == "created") {
          projectFiles.current = [...projectFiles.current, notification.file];
          onCreate?.(notification.file);
          const newTree = projectToTree(project, projectFiles.current);
          setTree(newTree);
        
        } else if (notification.event == "deleted") {
          const toKeep = projectFiles.current.filter(file => {
            const keep = !((file.path === notification.path) || (notification.path.endsWith("/") && file.path.startsWith(notification.path)))
            if (!keep) {
              onDelete?.(file.path);
            }
            return keep;
          });
          projectFiles.current = toKeep;
          const newTree = projectToTree(project, projectFiles.current);
          setTree(newTree);
        
        } else if (notification.event == "moved") {
          onMove?.(notification.old_path, notification.file)
          projectFiles.current.find(_ => _.path == notification.old_path).path = notification.file.path;
          const newTree = projectToTree(project, projectFiles.current);
          setTree(newTree);
        }
      }
    });

    // Cleanup
    return () => {
      notifications.current?.close();
      notifications.current = null; 
    };
  }, []);

  function toast(message: string) {
    const newToasts = [...toasts, {id: (toastId.current += 1), body: message}];
    setToasts(newToasts);
  }

  function onClickInternal(node: NodeApi<NodeData>) {
    if (node.isLeaf) {
      const  file = projectFiles.current.find(_ => _.path == node.data.id)
      if (file)
        onOpen?.(file);
    }
  }

  function onDeleteInternal({ids, nodes}: {ids: string[], nodes: NodeApi<NodeData>[]}) {
    nodes.forEach(node => {
      if (node.data.id != "/") {
        api.delete_file(project.id, node.data.id).then(_ => {
          /*
            // Updated asynchronously by notifications
            const toKeep = projectFiles.current.filter(file => {
              const keep = !((file.path === node.data.id) || (node.isInternal && file.path.startsWith(node.data.id)))
              if (!keep)
                onDelete?.(file.path);
              return keep;
            });
            projectFiles.current = toKeep;
            const newTree = projectToTree(project, projectFiles.current);
            setTree(newTree);
          */
        });  
      }
    });
  }

  function onMoveInternal({dragIds, dragNodes, parentId, parentNode}: {dragIds: string[], dragNodes: NodeApi<NodeData>[], parentId: string | null, parentNode: NodeApi<NodeData> | null}) {
    if (parentNode === null || parentNode.isRoot) // Not the same as isRoot from projectToTree
      parentId = "/";

    dragNodes.forEach(node => {
      const newPath = `${parentId}${node.data.name}${node.isLeaf ? "" : "/"}`;

      api.move_file(project.id, node.data.id, newPath).then(_ => {
        /*
          // Updated asynchronously by notifications
          projectFiles.current.find(_ => _.path == node.data.id).path = newPath;
          const newTree = projectToTree(project, projectFiles.current);
          setTree(newTree);
        */
      }).catch(error => {
        if (error.code == ErrorCode.BadParameter)
          toast(error.parameters[0].issue);
        else
          toast(error.message);
      });
    });
  };

  // TODO: might be useless with notifications
  function onEditInternal({id, name, node} : {id: string, name: string, node: NodeApi<NodeData>}) {
    /*
      const file = projectFiles.current.find(_ => _.path == id);
      const components = file.path.split('/');
      if (file.is_directory)
        components[components.length - 2] = name;
      else
        components[components.length - 1] = name;
      file.path = components.join('/');

      const newTree = projectToTree(project, projectFiles.current);
      setTree(newTree);
    */
  }

  function onCreateInternal({parentNode, type, parentId}: {parentId: string, parentNode: NodeApi<NodeData>, index: number, type: "internal" | "leaf"}) : Promise<{id: string}>  {    
    if (parentNode === null || parentNode.isRoot) // Not the same as isRoot from projectToTree
      parentId = "/";

    if (type === "leaf") {
      let name = "file";
      while (projectFiles.current.find(_ => _.path == `${parentId}${name}`))
        name = `new_${name}`;
      const path = `${parentId}${name}`;
      return api.create_file(project.id, path).then(file => {
        /*
          // Updated asynchronously by notifications
          projectFiles.current = [...projectFiles.current, file];
          const newTree = projectToTree(project, projectFiles.current);
          setTree(newTree);
        */ 
        return {id: file.path};
      });  
    } else {
      let name = "directory";
      while (projectFiles.current.find(_ => _.path == `${parentId}${name}/`) != undefined)
        name = `new_${name}`;
      const path = `${parentId}${name}/`;

      return api.create_directory(project.id, path).then(file => {
        //onCreate?.(file);
        /*
          // Updated asynchronously by notifications
          projectFiles.current = [...projectFiles.current, file];
          const newTree = projectToTree(project, projectFiles.current);
          setTree(newTree);
        */
        return {id: file.path};  
      });
    }
  }

  function FolderArrow({node}: {node: NodeApi<NodeData>}) {
    if (node.isLeaf || node.isEditing) return <></>;
    return node.isOpen ? <RiArrowDownSLine/> : <RiArrowRightSLine/>;
  }

  function Input({ node }: { node: NodeApi<NodeData> }) {
    const [editFeedback, setEditFeedback] = useState(null);

    return (
      <Form.Group >
        <Form.Control
          size={"sm"}
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

              if (file.path != path)
                api.move_file(project.id, file.path, path).then(_ => {
                  node.submit(name);
                }).catch(error => {
                  if (error.code == ErrorCode.BadParameter)
                    setEditFeedback(error.parameters[0].issue);
                  else
                    setEditFeedback(error.message);
                });
              else
                node.submit(name);
            }
          }}
        />
        <Form.Control.Feedback type="invalid">
          {editFeedback}
        </Form.Control.Feedback>
      </Form.Group>
    );
  }

  function NormalNode({node}: {node: NodeData}) {
    if (node.children != null)
      return <>
        {node.name}
        {/*<span className="ms-auto me-2"> <FaRegFile className="bigger-on-hover"/> </span>
        <span className="me-2"> <FaRegFolder className="bigger-on-hover" /> </span> */}
      </>;
    else if (node.name.endsWith(".recipe"))
      return <>{node.name}<span className="ms-auto me-2"><GrPlay className="bigger-on-hover" onClick={() => onRun?.(node.id)}/></span></>
    else
      return <>{node.name}</>;
  }

  function Node({node, tree, style, dragHandle}: NodeRendererProps<NodeData>) {
    const classNames = [];
    if (node.data.isRoot == true)
      classNames.push("root-item");
    if (node.isEditing)
      classNames.push("edit-item");
    if (node.willReceiveDrop)
      classNames.push("will-receive-drop-item");

    return (
      <Stack
        ref={dragHandle}
        style={style}
        onClick={() => node.isInternal && node.toggle()}
        className={classNames.join(' ')}
        direction="horizontal"
      >
        <FolderArrow node={node} />
        {node.isEditing ? <Input node={node}/> : <NormalNode node={node.data}/>}
      </Stack>
    );
  }

  function Cursor() {
    return <></>;
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
        onMove={onMoveInternal}
        onDelete={onDeleteInternal}
        onActivate={onClickInternal}
        renderCursor={Cursor}
        disableEdit={_ => _.isRoot === true}
        disableDrag={_ => _.isRoot === true}
      >{Node}</Tree>
       <ToastContainer
          className="p-3"
          position="bottom-start"
          style={{ zIndex: 1 }}
        >
          {toasts.map(toast => 
            <Toast key={toast.id} onClose={_ => setToasts(toasts.filter(_ => _.id != toast.id))} animation={true} bg="warning">
              <Toast.Header>
                <strong className="me-auto">Error</strong>
                <small>11 mins ago</small>
              </Toast.Header>
              <Toast.Body>{toast.body}</Toast.Body>
            </Toast>
          )}
        </ToastContainer>
    </div>
  );
}