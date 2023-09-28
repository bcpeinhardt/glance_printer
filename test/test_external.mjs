import fs from "node:fs"
import path from "node:path"

export function isFile(filepath) {
    let fp = path.normalize(filepath)
    return fs.existsSync(fp) && fs.lstatSync(fp).isFile();
}