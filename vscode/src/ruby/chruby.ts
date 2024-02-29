import os from "os";
import path from "path";

import * as vscode from "vscode";

import {
  VersionManager,
  ManagerIdentifier,
  RubyVersion,
} from "./versionManager";

export class Chruby extends VersionManager {
  readonly rubyInstallationUris = [
    vscode.Uri.joinPath(this.rootUri, "opt", "rubies"),
    vscode.Uri.joinPath(vscode.Uri.file(os.homedir()), ".rubies"),
  ];

  // Detect if Chruby is being used
  async detect(): Promise<boolean> {
    // Chruby is not supported on Windows
    if (os.platform() === "win32") {
      return false;
    }

    // If the user specified that they are using Chruby, trust them and proceed with trying to activate it
    if (this.configuredManager === ManagerIdentifier.Chruby) {
      return true;
    }

    this.outputChannel.info("Checking if Chruby is being used");
    for (const uri of this.rubyInstallationUris) {
      try {
        await vscode.workspace.fs.stat(uri);
        this.outputChannel.info("Discovered chruby");
        return true;
      } catch (_error: any) {
        continue;
      }
    }

    return false;
  }

  // Returns the Ruby version information including version and engine. E.g.: ruby-3.3.0, truffleruby-21.3.0
  async discoverRubyVersion(): Promise<RubyVersion> {
    let uri = this.bundleUri;
    const root = path.parse(uri.fsPath).root;

    while (uri.fsPath !== root) {
      try {
        const rubyVersionUri = vscode.Uri.joinPath(uri, ".ruby-version");
        const content = await vscode.workspace.fs.readFile(rubyVersionUri);
        const version = content.toString().trim();

        if (version === "") {
          throw new Error(`Ruby version file ${rubyVersionUri} is empty`);
        }

        const match =
          /((?<engine>[A-Za-z]+)-)?(?<version>\d\.\d\.\d(-[A-Za-z0-9]+)?)/.exec(
            version,
          );

        if (!match?.groups) {
          throw new Error(
            `Ruby version file ${rubyVersionUri} contains invalid format. Expected engine-version, got ${version}`,
          );
        }

        this.outputChannel.info(
          `Discovered Ruby version ${version} from ${rubyVersionUri.toString()}`,
        );
        return { engine: match.groups.engine, version: match.groups.version };
      } catch (error: any) {
        // If the file doesn't exist, continue going up the directory tree
        uri = vscode.Uri.file(path.dirname(uri.fsPath));
        continue;
      }
    }

    throw new Error("No .ruby-version file was found");
  }

  // Returns the full URI to the Ruby executable
  async findRubyUri(rubyVersion: RubyVersion): Promise<vscode.Uri> {
    const fullRubyName = rubyVersion.engine
      ? `${rubyVersion.engine}-${rubyVersion.version}`
      : rubyVersion.version;

    for (const uri of this.rubyInstallationUris) {
      const installationUri = vscode.Uri.joinPath(uri, fullRubyName);

      try {
        await vscode.workspace.fs.stat(installationUri);
        return vscode.Uri.joinPath(installationUri, "bin", "ruby");
      } catch (_error: any) {
        continue;
      }
    }

    throw new Error(
      `Cannot find installation directory for Ruby version ${fullRubyName}`,
    );
  }
}
