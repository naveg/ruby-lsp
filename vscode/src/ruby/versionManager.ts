import path from "path";
import os from "os";

import * as vscode from "vscode";

import { WorkspaceChannel } from "../workspaceChannel";
import { asyncExec } from "../common";

export enum ManagerIdentifier {
  Asdf = "asdf",
  Auto = "auto",
  Chruby = "chruby",
  Rbenv = "rbenv",
  Rvm = "rvm",
  None = "none",
  Custom = "custom",
}

export interface RubyVersion {
  version: string;
  engine?: string;
}

interface ActivationEnvironment {
  // The path where default gems are installed. Normally inside the Ruby installation unless overridden by the version
  // manager
  defaultGems: string;

  // The place where bundled gems are installed. E.g.: `~/.gem/ruby/3.0.0`
  gemHome: string;

  // Whether the activated Ruby has YJIT support
  yjit: boolean;
}

type ActivationResult = ActivationEnvironment & {
  // The URI to the Ruby executable
  rubyUri: vscode.Uri;

  // The version of Ruby that was activated (e.g. 3.0.0)
  version: string;
};

export abstract class VersionManager {
  protected readonly outputChannel: WorkspaceChannel;
  protected readonly workspaceFolder: vscode.WorkspaceFolder;
  protected readonly configuredManager: ManagerIdentifier;
  protected readonly bundleUri: vscode.Uri;
  // This rootUri is only used for testing purposes. Do not override the value in the constructor unless you're writing
  // a test
  protected readonly rootUri: vscode.Uri;
  private readonly customBundleGemfile?: string;

  // The URIs to the directories where Ruby might be installed for a given version manager
  abstract readonly rubyInstallationUris: vscode.Uri[];

  constructor(
    workspaceFolder: vscode.WorkspaceFolder,
    outputChannel: WorkspaceChannel,
    rootPath = os.platform() === "win32" ? "C:\\" : "/",
  ) {
    this.workspaceFolder = workspaceFolder;
    this.outputChannel = outputChannel;
    this.rootUri = vscode.Uri.file(rootPath);
    this.configuredManager = vscode.workspace
      .getConfiguration("rubyLsp")
      .get("rubyVersionManager")!;

    const customBundleGemfile: string = vscode.workspace
      .getConfiguration("rubyLsp")
      .get("bundleGemfile")!;

    if (customBundleGemfile.length > 0) {
      this.customBundleGemfile = path.isAbsolute(customBundleGemfile)
        ? customBundleGemfile
        : path.resolve(
            path.join(this.workspaceFolder.uri.fsPath, customBundleGemfile),
          );
    }

    this.bundleUri = this.customBundleGemfile
      ? vscode.Uri.file(path.dirname(this.customBundleGemfile))
      : workspaceFolder.uri;
  }

  // Activate the Ruby environment for the workspace
  async activate(): Promise<ActivationResult> {
    const versionInfo = await this.discoverRubyVersion();
    const rubyUri = await this.findRubyUri(versionInfo);
    const activationResult = await this.runActivationScript(rubyUri);
    this.runVersionCheck(versionInfo.version);

    const activationLog = Object.entries(activationResult)
      .map(([key, value]) => `${key}=${value}`)
      .join(", ");

    this.outputChannel.info(`Activated Ruby environment: ${activationLog}`);

    return {
      ...activationResult,
      version: versionInfo.version,
      rubyUri,
    };
  }

  // Detect if the current version manager is the correct one for the workspace
  abstract detect(): Promise<boolean>;

  // Read the Ruby version information from the manager's configuration files
  abstract discoverRubyVersion(): Promise<RubyVersion>;

  // Find the Ruby installation URI for the given version
  abstract findRubyUri(rubyVersion: RubyVersion): Promise<vscode.Uri>;

  // Run the activation script using the Ruby installation we found so that we can discover gem paths
  protected async runActivationScript(
    rubyExecutableUri: vscode.Uri,
  ): Promise<ActivationEnvironment> {
    // Typically, GEM_HOME points to $HOME/.gem/ruby/version_without_patch. For example, for Ruby 3.2.2, it would be
    // $HOME/.gem/ruby/3.2.0. However, certain version managers override GEM_HOME to use the patch part of the version,
    // resulting in $HOME/.gem/ruby/3.2.2. In our activation script, we check if a directory using the patch exists and
    // then prefer that over the default one.
    //
    // Note: this script follows an odd code style to avoid the usage of && or ||, which lead to syntax errors in
    // certain shells if not properly escaped (Windows)
    const script = [
      "user_dir = Gem.user_dir",
      "paths = Gem.path",
      "if paths.length > 2",
      "  paths.delete(Gem.default_dir)",
      "  paths.delete(Gem.user_dir)",
      "  if paths[0]",
      "    user_dir = paths[0] if Dir.exist?(paths[0])",
      "  end",
      "end",
      "newer_gem_home = File.join(File.dirname(user_dir), RUBY_VERSION)",
      "gems = (Dir.exist?(newer_gem_home) ? newer_gem_home : user_dir)",
      "data = { defaultGems: Gem.default_dir, gemHome: gems, yjit: !!defined?(RubyVM::YJIT) }",
      "STDERR.print(JSON.dump(data))",
    ].join(";");

    const result = await asyncExec(
      `${rubyExecutableUri.fsPath} -rjson -e '${script}'`,
      { cwd: this.bundleUri.fsPath },
    );

    return JSON.parse(result.stderr);
  }

  protected runVersionCheck(version: string) {
    const [major, _minor, _patch] = version.split(".").map(Number);

    if (major < 3) {
      throw new Error(
        `The Ruby LSP requires Ruby 3.0 or newer to run. This project is using ${version}. \
        [See alternatives](https://github.com/Shopify/vscode-ruby-lsp?tab=readme-ov-file#ruby-version-requirement)`,
      );
    }
  }
}
