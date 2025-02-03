import { BrowserRouter, Routes, Route } from "react-router";
import Api from "../api";
import Login from "./login";
import Register from "./register";

const api = new Api();

export default function App() {
  return <BrowserRouter>

    <Routes>
      <Route path="/login" element={<Login api={api} redirectTo={null}/>} />
    </Routes>
  
    <Routes>
      <Route path="/register" element={<Register api={api} redirectTo={null}/>} />
    </Routes>
    
  </BrowserRouter>;
}