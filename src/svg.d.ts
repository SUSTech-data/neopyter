// https://github.com/jupyterlab/jupyterlab/tree/main/packages/ui-components#how-to-create-a-new-labicon-from-an-external-svg-file

declare module '*.svg' {
  const value: string
  export default value
}
