////////////////////////////////////////////////////////////////////////////////
// Subsystem "Print".
//
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
// Open Office Writer - specific functions.
//
// Description of a reference to a print form and layout.
// Structure with fields:
// ServiceManager - service manager, service open office.
// Desktop - application Open Office (service UNO).
// Document - document (print form).
// Type - type of print form ("ODT").
//
////////////////////////////////////////////////////////////////////////////////

#Region ServiceProceduresAndFunctions

// Initialization of a print form: creates COM - object,
// properties are set to it.
Function InitializePrintFormOOWriter(Val Pattern = Undefined) Export
	
	Try
		ServiceManager = New COMObject("com.sun.star.ServiceManager");
	Except
		EventLogMonitorClient.AddMessageForEventLogMonitor(EventLogMonitorEvent(), "Error",
			NStr("en = 'An error occurred when connecting to the service manager (com.sun.star.ServiceManager).'") + 
			+ Chars.LF + DetailErrorDescription(ErrorInfo()),,True);
		FailedToGeneratePrintForm(ErrorInfo());
	EndTry;
	
	Try
		Desktop = ServiceManager.CreateInstance("com.sun.star.frame.Desktop");
	Except
		EventLogMonitorClient.AddMessageForEventLogMonitor(EventLogMonitorEvent(), "Error",
			NStr("en = 'An error occurred when running the Desktop service (com.sun.star.frame.Desktop).'") + 
			+ Chars.LF + DetailErrorDescription(ErrorInfo()),,True);
		FailedToGeneratePrintForm(ErrorInfo());
	EndTry;
	
	Parameters = GetComSafeArray();
	
#If Not WebClient Then
	Parameters.SetValue(0, ValueProperty(ServiceManager, "Hidden", True));
#EndIf
	
	Document = Desktop.ImportComponentFromURL("private:factory/swriter", "_blank", 0, Parameters);
	
#If WebClient Then
	Document.getCurrentController().getFrame().getContainerWindow().setVisible(False);
#EndIf

    // Configure fields by the template.
	If Pattern <> Undefined Then
		TemplateStyleName = Pattern.Document.CurrentController.getViewCursor().PageStyleName;
		TemplateStyle = Pattern.Document.StyleFamilies.getByName("PageStyles").getByName(TemplateStyleName);
			
		StyleName = Document.CurrentController.getViewCursor().PageStyleName;
		Style = Document.StyleFamilies.getByName("PageStyles").getByName(StyleName);
		
		Style.TopMargin = TemplateStyle.TopMargin;
		Style.LeftMargin = TemplateStyle.LeftMargin;
		Style.RightMargin = TemplateStyle.RightMargin;
		Style.BottomMargin = TemplateStyle.BottomMargin;
	EndIf;

	// Prepare a reference to the layout.
	Handler = New Structure("ServiceManager,Desktop,Document,Type");
	Handler.ServiceManager = ServiceManager;
	Handler.Desktop = Desktop;
	Handler.Document = Document;
	
	Return Handler;
	
EndFunction

// Returns a structure with the print form layout.
//
// Parameters:
// TemplateBinaryData - BinaryData - binary data of layout.
// Returns:
// structure - ref layout
//
Function GetOOWriterTemplate(Val PatternBinaryData, TempFileName) Export
	
	Handler = New Structure("ServiceManager,Desktop,Document,FileName");
	
	Try
		ServiceManager = New COMObject("com.sun.star.ServiceManager");
	Except
		EventLogMonitorClient.AddMessageForEventLogMonitor(EventLogMonitorEvent(), "Error",
			NStr("en = 'An error occurred when connecting to the service manager (com.sun.star.ServiceManager).'") + 
			+ Chars.LF + DetailErrorDescription(ErrorInfo()),,True);
		FailedToGeneratePrintForm(ErrorInfo());
	EndTry;
	
	Try
		Desktop = ServiceManager.CreateInstance("com.sun.star.frame.Desktop");
	Except
		EventLogMonitorClient.AddMessageForEventLogMonitor(EventLogMonitorEvent(), "Error",
			NStr("en = 'An error occurred when running the Desktop service (com.sun.star.frame.Desktop).'") + 
			+ Chars.LF + DetailErrorDescription(ErrorInfo()),,True);
		FailedToGeneratePrintForm(ErrorInfo());
	EndTry;
	
#If Not WebClient Then
	TempFileName = GetTempFileName("ODT");
	PatternBinaryData.Write(TempFileName);
#EndIf
	
	Parameters = GetComSafeArray();
#If Not WebClient Then
	Parameters.SetValue(0, ValueProperty(ServiceManager, "Hidden", True));
#EndIf
	
	Document = Desktop.ImportComponentFromURL("file:///" + StrReplace(TempFileName, "\", "/"), "_blank", 0, Parameters);
	
#If WebClient Then
	Document.getCurrentController().getFrame().getContainerWindow().setVisible(False);
#EndIf
	
	// Prepare a reference to the layout.
	Handler.ServiceManager = ServiceManager;
	Handler.Desktop = Desktop;
	Handler.Document = Document;
	Handler.FileName = TempFileName;
	
	Return Handler;
	
EndFunction

// Closes a layout of the print form and rewrites refs to COM object.
//
Function CloseConnection(Handler, Val CloseApplication) Export
	
	If CloseApplication Then
		Handler.Document.Close(0);
	EndIf;
	
	Handler.Document = Undefined;
	Handler.Desktop = Undefined;
	Handler.ServiceManager = Undefined;
	ScriptControl = Undefined;
	
	If Handler.Property("FileName") Then
		DeleteFiles(Handler.FileName);
	EndIf;
	
	Handler = Undefined;
	
EndFunction

// Sets a visible property for application OO Writer.
// Handler - reference to print form.
//
Procedure ShowOOWriterDocument(Val Handler) Export
	
	ContainerWindow = Handler.Document.getCurrentController().getFrame().getContainerWindow();
	ContainerWindow.setVisible(True);
	ContainerWindow.SetFocus();
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Working with layout

// Receives an area from the layout.
// Parameters:
// Handler - reference
// to layout AreaName - area name in the layout.
// ShiftBegin - shift from the
// 				area start default offset: 1 - means that the area
// 				is taken without a newline character after the operator parenthesis of the area opening.
// ShiftEnd - shift from the
// 				area end, default offset: -11 - means that the area
// 				is taken without a newline character before the operator parenthesis of the area closure.
//
Function GetTemplateArea(Val Handler, Val AreaName) Export
	
	Result = New Structure("Document,Start,End");
	
	Result.Start = GetAreaBeginPosition(Handler.Document, AreaName);
	Result.End   = GetAreaEndPosition(Handler.Document, AreaName);
	Result.Document = Handler.Document;
	
	Return Result;
	
EndFunction

// Receives a header area.
//
Function GetTopFooterArea(Val TemplateReference) Export
	
	Return New Structure("Document, ServiceManager", TemplateReference.Document, TemplateReference.ServiceManager);
	
EndFunction

// Receives a footer area.
//
Function GetLowerFooterArea(TemplateReference) Export
	
	Return New Structure("Document, ServiceManager", TemplateReference.Document, TemplateReference.ServiceManager);
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Work with a print form

// Inserts a line break.
// Parameters:
// Handler - Ref to WS Word document in which it is required to insert a line break.
//
Procedure InsertBreakAtNewLine(Val Handler) Export
	
	oText = Handler.Document.gettext();
	oCursor = oText.createTextCursor();
	oCursor.gotoEnd(False);
	oText.insertControlCharacter(oCursor, 0, False);
	
EndProcedure

// Adds a header to the print form.
//
Procedure AddHeader(Val PrintForm,
									Val Area) Export
	
	Template_oTxtCrsr = SetMainCursorOnHeader(Area);
	While Template_oTxtCrsr.goRight(1, True) Do
	EndDo;
	TransferableObject = Area.Document.getCurrentController().Frame.controller.getTransferable();
	
	SetMainCursorOnHeader(PrintForm);
	PrintForm.Document.getCurrentController().insertTransferable(TransferableObject);
	
EndProcedure

// Adds a footer to the print form.
//
Procedure AddFooter(Val PrintForm,
									Val Area) Export
	
	Template_oTxtCrsr = SetMainCursorOnFooter(Area);
	While Template_oTxtCrsr.goRight(1, True) Do
	EndDo;
	TransferableObject = Area.Document.getCurrentController().Frame.controller.getTransferable();
	
	SetMainCursorOnFooter(PrintForm);
	PrintForm.Document.getCurrentController().insertTransferable(TransferableObject);
	
EndProcedure

// Adds the area to print form from the template
// while replacing the parameters in the area with values from object data.
// Applied at single area output.
//
// Parameters:
// PrintForm - reference to print form.
// AreaHandler - area ref in the layout.
// TransitionToNextString - Boolean, whether it is required to insert break after area output.
//
// Returns:
// AreaCoordinates
//
Procedure JoinArea(Val PrintFormHandler,
							Val AreaHandler,
							Val TransitionToNextString = True,
							Val JoinTableString = False) Export
	
	Template_oTxtCrsr = AreaHandler.Document.getCurrentController().getViewCursor();
	Template_oTxtCrsr.gotoRange(AreaHandler.Start, False);
	
	If Not JoinTableString Then
		Template_oTxtCrsr.goRight(1, False);
	EndIf;
	
	Template_oTxtCrsr.gotoRange(AreaHandler.End, True);
	
	TransferableObject = AreaHandler.Document.getCurrentController().Frame.controller.getTransferable();
	PrintFormHandler.Document.getCurrentController().insertTransferable(TransferableObject);
	
	If JoinTableString Then
		DeleteLine(PrintFormHandler);
	EndIf;
	
	If TransitionToNextString Then
		InsertBreakAtNewLine(PrintFormHandler);
	EndIf;
	
EndProcedure

// Fills out parameters in a tabular field of the print form.
//
Procedure FillParameters(PrintForm, Data) Export
	
	For Each KeyValue IN Data Do
		If TypeOf(KeyValue) <> Type("Array") Then
			ReplacementString = KeyValue.Value;
			If IsTempStorageURL(ReplacementString) Then
				#If WebClient Then
					TempFileName = TempFilesDir() + String(New UUID) + ".tmp";
				#Else
					TempFileName = GetTempFileName("tmp");
				#EndIf
				BinaryData = GetFromTempStorage(ReplacementString);
				BinaryData.Write(TempFileName);
				
				TextGraphicObject = PrintForm.Document.CreateInstance("com.sun.star.text.TextGraphicObject");
				FileURL = FileNameInURL(TempFileName);
				TextGraphicObject.GraphicURL = FileURL;
				
				Document = PrintForm.Document;
				SearchDescriptor = Document.CreateSearchDescriptor();
				SearchDescriptor.SearchString = "{v8 " + KeyValue.Key + "}";
				SearchDescriptor.SearchCaseSensitive = False;
				SearchDescriptor.SearchWords = False;
				Found = Document.FindFirst(SearchDescriptor);
				While Found <> Undefined Do
					Found.GetText().InsertTextContent(Found.gettext(), TextGraphicObject, True);
					Found = Document.FindNext(Found.End, SearchDescriptor);
				EndDo;
			Else
				PF_oDoc = PrintForm.Document;
				PF_ReplaceDescriptor = PF_oDoc.createReplaceDescriptor();
				PF_ReplaceDescriptor.SearchString = "{v8 " + KeyValue.Key + "}";
				PF_ReplaceDescriptor.ReplaceString = String(KeyValue.Value);
				PF_oDoc.replaceAll(PF_ReplaceDescriptor);
			EndIf;
		EndIf;
	EndDo;
	
EndProcedure

// Adds a collection area to the print form.
//
Procedure JoinAndFillCollection(Val PrintFormHandler,
										  Val AreaHandler,
										  Val Data,
										  Val ThisTableRow = False,
										  Val TransitionToNextString = True) Export
	
	Template_oTxtCrsr = AreaHandler.Document.getCurrentController().getViewCursor();
	Template_oTxtCrsr.gotoRange(AreaHandler.Start, False);
	
	If Not ThisTableRow Then
		Template_oTxtCrsr.goRight(1, False);
	EndIf;
	Template_oTxtCrsr.gotoRange(AreaHandler.End, True);
	
	TransferableObject = AreaHandler.Document.getCurrentController().Frame.controller.getTransferable();
	
	For Each RowWithData IN Data Do
		PrintFormHandler.Document.getCurrentController().insertTransferable(TransferableObject);
		If ThisTableRow Then
			DeleteLine(PrintFormHandler);
		EndIf;
		FillParameters(PrintFormHandler, RowWithData);
	EndDo;
	
	If TransitionToNextString Then
		InsertBreakAtNewLine(PrintFormHandler);
	EndIf;
	
EndProcedure

// Sets a cursor at the end of document DocumentRef.
//
Procedure SetMainCursorOnDocumentBody(Val DocumentRef) Export
	
	oDoc = DocumentRef.Document;
	oViewCursor = oDoc.getCurrentController().getViewCursor();
	oTextCursor = oDoc.Text.createTextCursor();
	oViewCursor.gotoRange(oTextCursor, False);
	oViewCursor.gotoEnd(False);
	
EndProcedure

// Sets the cursor at the page header.
//
Function SetMainCursorOnHeader(Val DocumentRef) Export
	
	xCursor = DocumentRef.Document.getCurrentController().getViewCursor();
	PageStyleName = xCursor.getPropertyValue("PageStyleName");
	oPStyle = DocumentRef.Document.getStyleFamilies().getByName("PageStyles").getByName(PageStyleName);
	oPStyle.HeaderIsOn = True;
	HeaderTextCursor = oPStyle.getPropertyValue("HeaderText").createTextCursor();
	xCursor.gotoRange(HeaderTextCursor, False);
	Return xCursor;
	
EndFunction

// Sets the cursor at the footer.
//
Function SetMainCursorOnFooter(Val DocumentRef) Export
	
	xCursor = DocumentRef.Document.getCurrentController().getViewCursor();
	PageStyleName = xCursor.getPropertyValue("PageStyleName");
	oPStyle = DocumentRef.Document.getStyleFamilies().getByName("PageStyles").getByName(PageStyleName);
	oPStyle.FooterIsOn = True;
	FooterTextCursor = oPStyle.getPropertyValue("FooterText").createTextCursor();
	xCursor.gotoRange(FooterTextCursor, False);
	Return xCursor;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Other procedures and functions.

// Receives a special structure using which parameters
// are set for UNO objects.
//
Function ValueProperty(Val ServiceManager, Val Property, Val Value)
	
	PropertyValue = ServiceManager.Bridge_GetStruct("com.sun.star.beans.PropertyValue");
	PropertyValue.Name = Property;
	PropertyValue.Value = Value;
	
	Return PropertyValue;
	
EndFunction

Function GetAreaBeginPosition(Val xDocument, Val AreaName)
	
	TextForSearch = "{v8 Area." + AreaName + "}";
	
	xSearchDescr = xDocument.createSearchDescriptor();
	xSearchDescr.SearchString = TextForSearch;
	xSearchDescr.SearchCaseSensitive = False;
	xSearchDescr.SearchWords = True;
	xFound = xDocument.findFirst(xSearchDescr);
	If xFound = Undefined Then
		Raise NStr("en = 'The beginning of the layout area is not found:'") + " " + AreaName;	
	EndIf;
	Return xFound.End;
	
EndFunction

Function GetAreaEndPosition(Val xDocument, Val AreaName)
	
	TextForSearch = "{/v8 Area." + AreaName + "}";
	
	xSearchDescr = xDocument.createSearchDescriptor();
	xSearchDescr.SearchString = TextForSearch;
	xSearchDescr.SearchCaseSensitive = False;
	xSearchDescr.SearchWords = True;
	xFound = xDocument.findFirst(xSearchDescr);
	If xFound = Undefined Then
		Raise NStr("en = 'The end of the layout area is not found:'") + " " + AreaName;	
	EndIf;
	Return xFound.Start;
	
EndFunction

Procedure DeleteLine(PrintFormHandler)
	
	oFrame = PrintFormHandler.Document.getCurrentController().Frame;
	
	dispatcher = PrintFormHandler.ServiceManager.CreateInstance ("com.sun.star.frame.DispatchHelper");
	
	oViewCursor = PrintFormHandler.Document.getCurrentController().getViewCursor();
	
	dispatcher.executeDispatch(oFrame, ".uno:GoUp", "", 0, GetComSafeArray());
	
	While oViewCursor.TextTable <> Undefined Do
		dispatcher.executeDispatch(oFrame, ".uno:GoUp", "", 0, GetComSafeArray());
	EndDo;
	
	dispatcher.executeDispatch(oFrame, ".uno:Delete", "", 0, GetComSafeArray());
	
	While oViewCursor.TextTable <> Undefined Do
		dispatcher.executeDispatch(oFrame, ".uno:GoDown", "", 0, GetComSafeArray());
	EndDo;
	
EndProcedure

Function GetComSafeArray()
	
#If WebClient Then
	scr = New COMObject("MSScriptControl.ScriptControl");
	scr.language = "javascript";
	scr.eval("Array=new Array()");
	Return scr.eval("Array");
#Else
	Return New COMSafeArray("VT_DISPATCH", 1);
#EndIf
	
EndFunction

Function EventLogMonitorEvent()
	Return NStr("en = 'Print'");
EndFunction

Procedure FailedToGeneratePrintForm(ErrorInfo)
#If WebClient Then
	CorrectionText = NStr("en = 'In case of the work through the web the Internet Explorer browser under Windows OS is required.'");
#Else		
	CorrectionText = "";	
#EndIf
	ErrorMessage = StringFunctionsClientServer.PlaceParametersIntoString(
		NStr("en = 'Failed to generate a print form: %1. 
			|To show print forms as OpenOffice.org Writer, it is required to install the OpenOffice.org package on the computer. %2'"),
		BriefErrorDescription(ErrorInfo), CorrectionText);
	Raise ErrorMessage;
EndProcedure

Function FileNameInURL(Val FileName)
	FileName = StrReplace(FileName, " ", "%20");
	FileName = StrReplace(FileName, "\", "/"); 
	Return "file:/" + "/localhost/" + FileName; 
EndFunction

#EndRegion