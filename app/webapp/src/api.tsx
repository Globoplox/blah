const API_SERVER_URI = process.env.API_SERVER_URI;

// Api error codes
export enum ErrorCode {
  Unauthorized = "unauthorized",
  InvalidCrdentials = "invalid_credentials",
  BadParameter = "bad_parameter",
  BadRequest = "bad_request",
  ServerError = "server_error",
  // This one is used to produce mock api error incase of network error on client side 
  NetworkError = "network",
}

type BaseError = {code: ErrorCode, error: string, message: string | null}

export type ParameterError = {code: ErrorCode.BadParameter, error: string, message: string | null, parameters : {name: string, issue: string}[]}
export type Error = ParameterError | BaseError

export class Api {

  #headers = new Headers({'content-type': 'application/json'})

  mapNetworkError(error: unknown): Promise<Error> {
      return Promise.reject({code: ErrorCode.NetworkError, error: "Network error", message: JSON.stringify(error)})
  }

  login(email: string, password: string, staySignedIn : boolean) : Promise<null | Error> {
    const body = {email, password, stay_signed: staySignedIn};

    return fetch(
      `${API_SERVER_URI}/login`, {method: "PUT", headers: this.#headers, body: JSON.stringify(body)}
    ).then(response => {
        if (response.ok)
            return null
        else 
            return response.json().then(_ => Promise.reject(_))
    }, this.mapNetworkError)
  }

  register(email: string, name: string, password: string, staySignedIn : boolean) : Promise<null | Error> {
    const body = {email, name, password, stay_signed: staySignedIn};

    return fetch(
      `${API_SERVER_URI}/register`, {method: "POST", headers: this.#headers, body: JSON.stringify(body)}
    ).then(response => {
        if (response.ok)
            return null
        else 
            return response.json().then(_ => Promise.reject(_))
    }, this.mapNetworkError)
  }
}

export default Api;