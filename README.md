# memechan



## Generating TypeScript Interfaces

To generate TypeScript interfaces of move smart contracts for the Memechan repo using the `sui-client-gen` tool, adhere to the following steps:

1. **sui-client-gen Installation**: Install `sui-client-gen` by following the instructions in the [sui-client-gen repository](https://github.com/kunalabs-io/sui-client-gen).

2. **Node Installation**: Make sure Node.js is installed on your system, following the version specified in the `.nvmrc` file.

3. **Dependency Installation**: Navigate to the `codegen` directory and install the required dependencies: `yarn install`

4. **Code Generation**: Execute the following command to generate TypeScript code for move smart: `yarn run generate`

5. **Code Quality Assurance**: After code generation, ensure code consistency and quality by running the following command: `yarn run fix:generated`. This command utilizes ESLint and Prettier to format and lint the generated code.

Please note that to maintain a manageable repository size, the generated code is not included in the repository.