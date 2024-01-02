export class RPCError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'RPCError';
  }
}
