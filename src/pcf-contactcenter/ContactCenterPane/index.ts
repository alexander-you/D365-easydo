import { IInputs, IOutputs } from "./generated/ManifestTypes";

/**
 * EasyDo.ContactCenterPane
 *
 * A thin standalone PCF control that hosts the contact-center productivity-pane
 * web resource (alex_/html/contactCenterPane.html) inside an iframe. It exists
 * only because a custom productivity tool must be a Control or a Custom Page —
 * an HTML web resource cannot be registered directly. The web resource is served
 * from the org domain, so it is same-origin with the app and keeps native access
 * to Xrm.WebApi and the Omnichannel client API through the frame chain.
 */
export class ContactCenterPane
  implements ComponentFramework.StandardControl<IInputs, IOutputs>
{
  private _container: HTMLDivElement;
  private _iframe: HTMLIFrameElement;
  private _src = "";

  private static readonly DEFAULT_WEB_RESOURCE =
    "alex_/html/contactCenterPane.html";

  public init(
    context: ComponentFramework.Context<IInputs>,
    _notifyOutputChanged: () => void,
    _state: ComponentFramework.Dictionary,
    container: HTMLDivElement
  ): void {
    this._container = container;
    this._container.classList.add("edo-cc-pane-host");

    this._iframe = document.createElement("iframe");
    this._iframe.className = "edo-cc-pane-frame";
    this._iframe.setAttribute("title", "easydo Contact Center");
    this._iframe.setAttribute("frameborder", "0");
    this._iframe.setAttribute("allow", "clipboard-read; clipboard-write");

    this._container.appendChild(this._iframe);

    this._src = this.buildSrc(context);
    this._iframe.src = this._src;
  }

  public updateView(context: ComponentFramework.Context<IInputs>): void {
    const next = this.buildSrc(context);
    if (next && next !== this._src) {
      this._src = next;
      this._iframe.src = next;
    }
  }

  public getOutputs(): IOutputs {
    return {};
  }

  public destroy(): void {
    if (this._iframe) {
      this._iframe.src = "about:blank";
    }
  }

  /** Resolve the absolute URL of the hosted web resource. */
  private buildSrc(context: ComponentFramework.Context<IInputs>): string {
    const wr =
      (context.parameters.webResource &&
        context.parameters.webResource.raw &&
        context.parameters.webResource.raw.trim()) ||
      ContactCenterPane.DEFAULT_WEB_RESOURCE;

    const base = this.getClientUrl(context).replace(/\/+$/, "");
    return base + "/WebResources/" + wr;
  }

  /**
   * Best-effort org client URL. context.page.getClientUrl is the supported PCF
   * accessor; fall back to the global Xrm context (present in the model-driven
   * shell) and finally to a relative path.
   */
  private getClientUrl(context: ComponentFramework.Context<IInputs>): string {
    try {
      const page = (context as unknown as { page?: { getClientUrl?: () => string } })
        .page;
      if (page && typeof page.getClientUrl === "function") {
        const url = page.getClientUrl();
        if (url) {
          return url;
        }
      }
    } catch (e) {
      /* ignore */
    }
    try {
      const xrm = (window as unknown as {
        Xrm?: { Utility?: { getGlobalContext?: () => { getClientUrl?: () => string } } };
      }).Xrm;
      const getGlobalContext = xrm && xrm.Utility && xrm.Utility.getGlobalContext;
      if (typeof getGlobalContext === "function") {
        const ctx = getGlobalContext();
        if (ctx && typeof ctx.getClientUrl === "function") {
          const url = ctx.getClientUrl();
          if (url) {
            return url;
          }
        }
      }
    } catch (e) {
      /* ignore */
    }
    return "";
  }
}
