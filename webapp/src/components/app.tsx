import { BrowserRouter, Routes, Route } from "react-router";
import Api, {ErrorCode, Error} from "../api";
import Login from "./login";
import Register from "./register";
import Index from "./index";
import CreateProject from "./create_project";
import Project from "./project";
import { useNavigate } from "react-router";
import Toast from 'react-bootstrap/Toast';
import {Variant} from 'react-bootstrap/types';
import ToastContainer from 'react-bootstrap/ToastContainer';
import { useState, useRef, useEffect } from 'react';

type Toast = {id: number, body: string, bg: Variant, title: string}

/*
  TODO:
  - Webapp errors
  - Api integration/regression tests testing
  - Recipe call from receipe (with parameters)
  - Documentation
  - Global cleanup
  - Fixing project.tsx
  - Re-open notifications sockets if closed when back to page ?
  - Error management
  - Self Profile page
  - Disconnect button in uri
  - Can access projects without user if project is public
  - All auth related chore (reset, doube auth, email verification, oauth, device kick, ...)
*/
export default function App() {
  
  const [toasts, setToasts] = useState([] as Toast[]);
  const toastId = useRef(0);

  function toast(body: string, title: string, bg: Variant) {
    const newToasts = [...toasts, {id: (toastId.current += 1), body, bg, title}];
    setToasts(newToasts);
  }

  function RedirectUnauthenticated({api}: {api: Api}) {
    const navigate = useNavigate();
    
    api.default_handlers["unauthenticated"] = (error) => {
      navigate(`/login?redirectTo=${location.pathname}`);
    };

    return <></>;
  }

  const api = new Api({
    "network": (error) => { toast(error.message, error.error, "danger") },
    "unauthorized": (error) => { toast(error.message, error.error, "danger") },
    "not_found": (error) => { toast(error.message, error.error, "danger") },
    "server_error": (error) => { toast(error.message, error.error, "danger") },
    "bad_request": (error) => { toast(error.message, error.error, "danger") },
    "quotas": (error) => { toast(error.message, error.error, "danger") }
  });

  return <>
    <BrowserRouter>
      <Routes>
        <Route index element={<Index api={api} />} />
        <Route path="login" element={<Login api={api}/>} />
        <Route path="register" element={<Register api={api}/>} />
        <Route path="project">
          <Route path="create" element={<CreateProject api={api} />} />
          <Route path=":projectId/file?/*" element={<Project api={api} />} />
        </Route>
      </Routes>
      <RedirectUnauthenticated api={api}/>
    </BrowserRouter>

    <ToastContainer
      className="p-3"
      position="bottom-start"
      style={{ zIndex: 1 }}
    >
      {toasts.map(toast => 
        <Toast key={toast.id} onClose={_ => setToasts(toasts.filter(_ => _.id != toast.id))} animation={true} bg={toast.bg}>
          <Toast.Header>
            <strong className="me-auto">{toast.title}</strong>
          </Toast.Header>
          <Toast.Body>{toast.body}</Toast.Body>
        </Toast>
      )}
    </ToastContainer>
  </>;
}