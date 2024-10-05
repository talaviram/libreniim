import * as fabric from "fabric";
export const canvas = new fabric.Canvas("labelCanvas");
window.canvas = canvas;

const MIN_FONT_SIZE = 16;
const MAX_FONT_SIZE = 100;
const DEFAULT_FONT_SIZE = 24;
const DEFAULT_OBJECT_SIZE = 25;
const ITEM_INSERT_OFFSET = 10;

var itemInsertCount = 0;
var currentQRObject = null;
var fillObject = true;

function getCurrentDateAsString() {
  const date = new Date();
  return date.toLocaleDateString();
}
function getCurrentTimeAsString() {
  const date = new Date();
  return date.toLocaleTimeString();
}

function getMakePositions() {
  const delta = ITEM_INSERT_OFFSET * itemInsertCount;
  return { left: 5 + delta, top: 5 + delta };
}

function makeNewObject(objectType) {
  const pos = getMakePositions();
  const fill = fillObject ? "black" : "transparent";
  const stroke = fillObject ? "transparent" : "black";
  let object;
  switch (objectType) {
    case "Text":
      object = new fabric.IText("Text", {
        left: pos.left,
        top: pos.top,
      });
      object.fontSize = DEFAULT_FONT_SIZE;
      break;
    case "Circle":
      object = new fabric.Circle({
        radius: DEFAULT_OBJECT_SIZE / 2,
        stroke: stroke,
        fill: fill,
        left: pos.left,
        top: pos.top,
      });
      break;
    case "Rect":
      object = new fabric.Rect({
        fill: fill,
        stroke: stroke,
        left: pos.left,
        top: pos.top,
        width: DEFAULT_OBJECT_SIZE,
        height: DEFAULT_OBJECT_SIZE,
      });
      break;
    case "Triangle":
      object = new fabric.Triangle({
        width: DEFAULT_OBJECT_SIZE,
        height: DEFAULT_OBJECT_SIZE,
        left: pos.left,
        top: pos.top,
        fill: fill,
        stroke: stroke,
      });
      break;
    case "LineH":
    default:
      object = new fabric.Line(
        [pos.left, pos.top, pos.left + DEFAULT_OBJECT_SIZE, pos.top],
        {
          stroke: "black",
          strokeWidth: 4,
        }
      );
      break;
  }
  itemInsertCount++;
  object.on("contextmenu", function () {
    event.preventDefault();
  });
  object.on("selection:cleared", function () {
    itemInsertCount = 0;
  });
  canvas.add(object);
  // hacky way to set bounded area
  canvas.setActiveObject(object);
}

function makeSymbol(svgString, onSymbolCreated) {
  // Parse the SVG string and add it to the canvas
  fabric.loadSVGFromString(svgString).then((parsed) => {
    const obj = fabric.util.groupSVGElements(parsed.objects);
    canvas.add(obj);
    canvas.setActiveObject(obj);
    canvas.renderAll();
    if (onSymbolCreated != undefined) onSymbolCreated(obj);
  });
}

function deleteSelectedObjects() {
  canvas.getActiveObjects().forEach((obj) => {
    canvas.remove(obj);
  });
  canvas.discardActiveObject();
}

const objectAlignStart = document.getElementById("align-start");
const objectAlignCenter = document.getElementById("align-center");
const objectAlignEnd = document.getElementById("align-end");
const objectAlignTop = document.getElementById("align-top");
const objectAlignBottom = document.getElementById("align-bottom");
const alignInspector = document.getElementById("align-inspector");
const toFrontButton = document.getElementById("to-front");
const toBackButton = document.getElementById("to-back");
const zInspector = document.getElementById("z-inspector");
const objectColorInspector = document.getElementById("object-color-inspector");
const objectFillWhiteButton = document.getElementById("fill-white");
const objectFillBlackButton = document.getElementById("fill-black");
const objectStrokeWhiteButton = document.getElementById("stroke-white");
const objectStrokeBlackButton = document.getElementById("stroke-black");

const qrInspector = document.getElementById("qr-inspector");
const qrSelectedText = document.getElementById("qr-text");
const textInspector = document.getElementById("text-inspector");
const textBold = document.getElementById("text-bold");
const textItalic = document.getElementById("text-italic");
const textUnderline = document.getElementById("text-underline");
const textStrikethrough = document.getElementById("text-strikethrough");
const textBlack = document.getElementById("text-black");
const textWhite = document.getElementById("text-white");

const fontFamilySelect = document.getElementById("font-family");
const fontSize = document.getElementById("font-size");
const fontSizePlus = document.getElementById("font-size-plus");
const fontSizeMinus = document.getElementById("font-size-minus");
const iTextEditor = document.getElementById("itext");

function handleSelectionChanged(options) {
  let isIText = false;
  let isQR = false;
  let canAlign = false;
  let isSimpleObject = false;
  let objs;

  if (options.selected) {
    const selectionColor = "black";
    canvas.selectionBorderColor = selectionColor;
    canvas.cornerColorColor = selectionColor;
    objs = options.selected;
    objs.forEach((obj) => {
      obj.set({ borderColor: selectionColor, cornerColor: selectionColor });
      obj.group;
    });
    isIText = objs[0] instanceof fabric.IText;
    isQR = objs[0].qrText != null && objs[0].qrText != undefined;
    if (objs.length === 1) {
      canAlign = true;
      const type = objs[0].type;
      isSimpleObject =
        type === "rect" ||
        type === "circle" ||
        type === "triangle" ||
        type === "line";
    }
  }
  textInspector.hidden = !isIText;
  if (isIText) {
    setTextInspectorIfNeeded(objs[0]);
  }
  qrInspector.hidden = !isQR;
  currentQRObject = isQR ? objs[0] : null;
  if (isQR) {
    qrText = objs[0].qrText;
  }
  alignInspector.hidden = !canAlign;
  zInspector.hidden = !canAlign;
  objectColorInspector.hidden = !isSimpleObject;
  if (!isSimpleObject) objectColorInspector.classList.add("hidden");
  else objectColorInspector.classList.remove("hidden");
}

function toggleClass(button, isActive) {
  const activeClass = ["active"];
  if (isActive) {
    button.classList.add(activeClass);
  } else {
    button.classList.remove(activeClass);
  }
}

function setTextInspectorIfNeeded(textItem) {
  for (let option in fontFamilySelect.children) {
    const currentFamily = textItem.get("fontFamily");
    let current = fontFamilySelect[option].value;
    fontFamilySelect[option].selected = current === currentFamily;
  }
  iTextEditor.value = canvas.getActiveObject().get("text");
  toggleClass(textBold, textItem.get("fontWeight") === "bold");
  toggleClass(textItalic, textItem.get("fontStyle") === "italic");
  toggleClass(textUnderline, textItem.get("underline"));
  toggleClass(textStrikethrough, textItem.get("linethrough"));
}

function appendTextToCurrentIText(text) {
  let obj = canvas.getActiveObject();
  const isIText = obj instanceof fabric.IText;
  if (!isIText) return null;
  const curText = obj.get("text");
  const addSpace = obj.text.length > 0;
  obj.set("text", curText + (addSpace ? " " : "") + text);
  canvas.renderAll();
}

function createQR() {
  const qrText = qrSelectedText.value;
  const generatedQR = new QRCode({
    msg: qrText,
    dim: 128,
    pad: 4,
    mtx: -1,
    ecl: "M",
    ecb: 1,
    pal: ["#000", "#fff"],
    vrb: 0,
  });
  makeSymbol("<svg>" + generatedQR.innerHTML + "/svg>", (obj) => {
    obj.qrText = qrText;
    obj.scaleToWidth(DEFAULT_OBJECT_SIZE * 2.5);
    canvas.renderAll();
    handleSelectionChanged({ selected: canvas.getActiveObjects() });
  });
}

function init() {
  document.getElementById("addTextButton").addEventListener("click", () => {
    makeNewObject("Text");
  });
  document.getElementById("addRectButton").addEventListener("click", () => {
    makeNewObject("Rect");
  });
  document.getElementById("addCircleButton").addEventListener("click", () => {
    makeNewObject("Circle");
  });
  document.getElementById("addTriangleButton").addEventListener("click", () => {
    makeNewObject("Triangle");
  });
  document.getElementById("addLineButton").addEventListener("click", () => {
    makeNewObject("Line");
  });
  document.getElementById("addQRButton").addEventListener("click", () => {
    createQR();
  });
  document.getElementById("text-current-time").addEventListener("click", () => {
    appendTextToCurrentIText(getCurrentTimeAsString());
  });
  document.getElementById("text-current-date").addEventListener("click", () => {
    appendTextToCurrentIText(getCurrentDateAsString());
  });

  textBold.addEventListener("click", () => {
    const isBold = textBold.classList.contains("active");
    if ((obj = setIfIText("fontWeight", isBold ? "normal" : "bold")))
      setTextInspectorIfNeeded(obj);
  });

  textItalic.addEventListener("click", () => {
    const isItalic = textItalic.classList.contains("active");
    if ((obj = setIfIText("fontStyle", isItalic ? "normal" : "italic")))
      setTextInspectorIfNeeded(obj);
  });

  textUnderline.addEventListener("click", () => {
    const isUnderline = !textUnderline.classList.contains("active");
    if ((obj = setIfIText("underline", isUnderline)))
      setTextInspectorIfNeeded(obj);
  });

  textStrikethrough.addEventListener("click", () => {
    const isStrikethrough = !textStrikethrough.classList.contains("active");
    if ((obj = setIfIText("linethrough", isStrikethrough)))
      setTextInspectorIfNeeded(obj);
  });

  textBlack.addEventListener("click", () => {
    canvas.getActiveObject().set("fill", "black");
    canvas.renderAll();
  });

  textWhite.addEventListener("click", () => {
    canvas.getActiveObject().set("fill", "white");
    canvas.renderAll();
  });

  // font controls
  fontFamilySelect.addEventListener("change", () => {
    if ((obj = setIfIText("fontFamily", fontFamilySelect.value)))
      setTextInspectorIfNeeded(obj);
  });
  fontSize.addEventListener("change", () => {
    if ((obj = setIfIText("fontSize", fontSize.value)))
      setTextInspectorIfNeeded(obj);
  });
  populateFontSize();
  fontSizePlus.addEventListener("click", () => {
    const incValue = Math.min(parseInt(fontSize.value) + 1, MAX_FONT_SIZE);
    setIfIText("fontSize", incValue);
    fontSize.value = incValue;
  });
  fontSizeMinus.addEventListener("click", () => {
    const decValue = Math.max(parseInt(fontSize.value) - 1, MIN_FONT_SIZE);
    setIfIText("fontSize", decValue);
    fontSize.value = decValue;
  });
  iTextEditor.addEventListener("input", () => {
    const obj = canvas.getActiveObject();
    if (obj.get("type") != "i-text") return;
    obj.set("text", iTextEditor.value);
    canvas.renderAll();
  });

  objectAlignTop.addEventListener("click", () => {
    alignObjectsOnCanvas(canvas.getActiveObjects(), "top");
  });
  objectAlignStart.addEventListener("click", () => {
    alignObjectsOnCanvas(canvas.getActiveObjects(), "left");
  });
  objectAlignCenter.addEventListener("click", () => {
    alignObjectsOnCanvas(canvas.getActiveObjects(), "center");
  });
  objectAlignEnd.addEventListener("click", () => {
    alignObjectsOnCanvas(canvas.getActiveObjects(), "right");
  });
  objectAlignBottom.addEventListener("click", () => {
    alignObjectsOnCanvas(canvas.getActiveObjects(), "bottom");
  });

  toFrontButton.addEventListener("click", () => {
    canvas.bringObjectToFront(canvas.getActiveObject());
    canvas.renderAll();
  });
  toBackButton.addEventListener("click", () => {
    canvas.sendObjectToBack(canvas.getActiveObject());
    canvas.renderAll();
  });

  objectStrokeBlackButton.addEventListener("click", () => {
    canvas.getActiveObject().set("stroke", "black");
    canvas.renderAll();
  });
  objectStrokeWhiteButton.addEventListener("click", () => {
    canvas.getActiveObject().set("stroke", "white");
    canvas.renderAll();
  });

  objectFillBlackButton.addEventListener("click", () => {
    canvas.getActiveObject().set("fill", "black");
    canvas.renderAll();
  });
  objectFillWhiteButton.addEventListener("click", () => {
    canvas.getActiveObject().set("fill", "white");
    canvas.renderAll();
  });

  qrSelectedText.addEventListener("input", () => {
    if (currentQRObject === null) return;
    const originalObject = currentQRObject;
    const qrText = qrSelectedText.value;
    const generatedQR = new QRCode({
      msg: qrText,
      dim: 512,
      pad: 4,
      mtx: -1,
      ecl: "M",
      ecb: 1,
      pal: ["#000", "#fff"],
      vrb: 0,
    });
    makeSymbol("<svg>" + generatedQR.innerHTML + "/svg>", (obj) => {
      obj.qrText = qrText;
      obj.left = originalObject.left;
      obj.top = originalObject.top;
      obj.width = originalObject.width;
      obj.height = originalObject.height;
      obj.angle = originalObject.angle;
      obj.scaleX = originalObject.scaleX;
      obj.scaleY = originalObject.scaleY;
      canvas.remove(originalObject);
      canvas.discardActiveObject(originalObject);
      canvas.setActiveObject(obj);
      canvas.renderAll();
      handleSelectionChanged({ selected: canvas.getActiveObjects() });
    });
  });

  document
    .getElementById("deleteSelectedButton")
    .addEventListener("click", deleteSelectedObjects);

  document.getElementById("selectAllButton").addEventListener("click", () => {
    canvas.discardActiveObject();
    const sel = new fabric.ActiveSelection(canvas.getObjects(), {
      canvas: canvas,
    });
    canvas.setActiveObject(sel);
    canvas.requestRenderAll();
  });

  canvas.on("selection:created", handleSelectionChanged);
  canvas.on("selection:cleared", handleSelectionChanged);
  canvas.on("selection:updated", handleSelectionChanged);

  const object = new fabric.IText("Label", {
    left: 0,
    top: 0,
    fontSize: 50,
  });
  canvas.add(object);
  alignObject(object, "center");
}

function setIfIText(prop, value) {
  let obj = canvas.getActiveObject();
  const isIText = obj instanceof fabric.IText;
  if (!isIText) return null;
  obj.set(prop, value);
  canvas.renderAll();
  return obj;
}

function alignObject(obj, alignment) {
  switch (alignment.toLowerCase()) {
    case "top":
      obj.set({
        top: 0,
      });
      break;
    case "left":
      obj.set({
        left: 0,
      });
      break;
    case "right":
      obj.set({
        left: canvas.width - obj.width,
      });
      break;
    case "bottom":
      obj.set({
        top: canvas.height - obj.height,
      });
      break;
    case "center":
      canvas.centerObject(obj);
      break;
    default:
      console.error("Invalid alignment:", alignment);
  }
  obj.setCoords();
  canvas.renderAll();
}

function alignObjectsOnCanvas(objects, alignType) {
  objects.forEach((obj) => {
    alignObject(obj, alignType);
  });
  canvas.renderAll();
}

// Predefined font list
const defaultFontFamilies = [
  "Arial",
  "Verdana",
  "Tahoma",
  "Trebuchet MS",
  "Times New Roman",
  "Georgia",
  "Garamond",
  "Courier New",
  "Brush Script MT",
];

// Populate font select elements
function populateFontFamilySelect() {
  let didSelectFirst = false;
  for (const font of defaultFontFamilies) {
    const option = document.createElement("option");
    option.value = font;
    option.text = font;
    if (!didSelectFirst) {
      didSelectFirst = true;
      option.selected = true;
    }
    fontFamilySelect.appendChild(option);
  }
}
populateFontFamilySelect();
function populateFontSize() {
  const defaultFontSize = 24;
  for (let i = MIN_FONT_SIZE; i <= MAX_FONT_SIZE; i++) {
    const option = document.createElement("option");
    option.value = i;
    option.text = i;
    if (defaultFontSize == i) {
      option.selected = true;
    }
    fontSize.appendChild(option);
  }
}

init();
