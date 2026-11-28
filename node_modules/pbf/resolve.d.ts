/**
 * Reads and parses a .proto file, merging in messages and enums from all the files it imports (directly or
 * transitively). Imports are looked up relative to the importing file, then in each of the include paths.
 * @param {string | URL} filename
 * @param {{paths?: (string | URL)[]}} [options] Include paths (like protoc's `-I`); the default is the
 * current working directory.
 */
export declare function resolve(filename: string | URL, { paths }?: {
    paths?: (string | URL)[];
}): any;
