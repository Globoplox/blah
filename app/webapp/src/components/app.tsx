import { BrowserRouter, Routes, Route } from "react-router";
import Api from "../api";
import Login from "./login";
import Register from "./register";
import Index from "./index";
import CreateProject from "./create_project";

const api = new Api();

export default function App() {
  return <BrowserRouter>

    <Routes>
      <Route index element={<Index api={api} />} />
      <Route path="login" element={<Login api={api} redirectTo={null}/>} />
      <Route path="register" element={<Register api={api} redirectTo={null}/>} />
      <Route path="project">
        <Route path="create" element={<CreateProject api={api} />} />
      </Route>
    </Routes>
  </BrowserRouter>;

}