////////////////////////////////////////////////////////////////////////////////
// Subsystem "Print".
//
////////////////////////////////////////////////////////////////////////////////

//////////////////////////////////////////////////////////////////////////////////
// Print using layouts of MS Word format.
//
// Description of data structures:
//
// Handler - structure used to connect to COM objects.
//  - COMConnection - COMObject
//  - Type - String - either "DOC" or "odt".
//  - FileName - String - template attachment file name (fill out only for templates).
//  - LastOutputType - type of the last output area 
//  - (see AreaType).
//
// Area in document
//  - COMConnection - COMObject
//  - Type - String - either "DOC" or "odt".
//  - Start - area start position.
//  - End - area end position.
//

#Region ServiceProceduresAndFunctions

// Establishes COM connection with COM object Word.Application,
// creates a single document in it.
//
Function InitializePrintFormMSWord(Template) Export
	
	Handler = New Structure("Type", "DOC");
	
	Try
		COMObject = New COMObject("Word.Application");
	Except
		EventLogMonitorClient.AddMessageForEventLogMonitor(EventLogMonitorEvent(), "Error",
			DetailErrorDescription(ErrorInfo()),,True);
		FailedToGeneratePrintForm(ErrorInfo());
	EndTry;
	
	Handler.Insert("COMConnection", COMObject);
	Try
		COMObject.Documents.Add();
	Except
		COMObject.Quit(0);
		COMObject = 0;
		EventLogMonitorClient.AddMessageForEventLogMonitor(EventLogMonitorEvent(), "Error",
			DetailErrorDescription(ErrorInfo()),,True);
		FailedToGeneratePrintForm(ErrorInfo());
	EndTry;
	

	TemplatePageSettings = Template; // For backward compatibility (the entering function parameter type is changed).
	If TypeOf(Template) = Type("Structure") Then
		TemplatePageSettings = Template.TemplatePageSettings;
		// Copying styles from the layout.
		Template.COMConnection.ActiveDocument.Close();
		Handler.COMConnection.ActiveDocument.CopyStylesFromTemplate(Template.FileName);
		Template.COMConnection.Documents.Open(Template.FileName);
	EndIf;
	
	// Copying page settings.
	If TemplatePageSettings <> Undefined Then
		For Each Setting IN TemplatePageSettings Do
			Try
				COMObject.ActiveDocument.PageSetup[Setting.Key] = Setting.Value;
			Except
				// Skip if the setting is not supported by the current application version.
			EndTry;
		EndDo;
	EndIf;
	// Remember a document view kind.
	Handler.Insert("ViewType", COMObject.Application.ActiveWindow.View.Type);	
	
	Return Handler;
	
EndFunction

// Establishes COM connection with COM object Word.Application
// and opens a template in it. Template file is saved based
// on the binary data passed in the function parameters.
//
// Parameters:
// TemplateBinaryData - BinaryData - binary data of layout.
// Returns:
// structure - ref layout
//
Function GetMSWordTemplate(Val TemplateBinaryData, Val TempFileName = "") Export
	
	Handler = New Structure("Type", "DOC");
	Try
		COMObject = New COMObject("Word.Application");
	Except
		EventLogMonitorClient.AddMessageForEventLogMonitor(EventLogMonitorEvent(), "Error",
			DetailErrorDescription(ErrorInfo()),,True);
		FailedToGeneratePrintForm(ErrorInfo());
	EndTry;
	
#If Not WebClient Then
	TempFileName = GetTempFileName("DOC");
	TemplateBinaryData.Write(TempFileName);
#EndIf
	
	Try
		COMObject.Documents.Open(TempFileName);
	Except
		COMObject.Quit(0);
		COMObject = 0;
		DeleteFiles(TempFileName);
		EventLogMonitorClient.AddMessageForEventLogMonitor(EventLogMonitorEvent(), "Error",
			DetailErrorDescription(ErrorInfo()),,True);
		Raise(NStr("en='Error on layout file opening';ru='Ошибка при открытии файла шаблона.'") + Chars.LF 
			+ BriefErrorDescription(ErrorInfo()));
	EndTry;
	
	Handler.Insert("COMConnection", COMObject);
	Handler.Insert("FileName", TempFileName);
	Handler.Insert("IsTemplate", True);
	
	Handler.Insert("TemplatePageSettings", New Map);
	
	For Each SettingName IN PageParametersSettings() Do
		Try
			Handler.TemplatePageSettings.Insert(SettingName, COMObject.ActiveDocument.PageSetup[SettingName]);
		Except
			// Skip if the setting is not supported by the current application version.
		EndTry;
	EndDo;
	
	Return Handler;
	
EndFunction

// Closes connection with COM object Word.Application.
// Parameters:
// Handler - ref to a print form or layout.
// CloseApplication - Boolean - whether it is required to close the application.
//
Procedure CloseConnection(Handler, Val CloseApplication) Export
	
	If CloseApplication Then
		Handler.COMConnection.Quit(0);
	EndIf;
	
	Handler.COMConnection = 0;
	
	#If Not WebClient Then
	If Handler.Property("FileName") Then
		DeleteFiles(Handler.FileName);
	EndIf;
	#EndIf
	
EndProcedure

// Sets a visible property for MS Word application.
// Handler - reference to print form.
//
Procedure ShowMSWordDocument(Val Handler) Export
	
	COMConnection = Handler.COMConnection;
	COMConnection.Application.Selection.Collapse();
	
	// Restore a document view kind.
	If Handler.Property("ViewType") Then
		COMConnection.Application.ActiveWindow.View.Type = Handler.ViewType;
	EndIf;
	
	COMConnection.Application.Visible = True;
	COMConnection.Activate();
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Function to receive areas from the layout.

// Receives an area from the layout.
//
// Parameters:
//  Handler - reference
//  to layout AreaName - area name in the layout.
//  ShiftBegin    - Number - overrides the area start boundary when the area does not
//                              start right after the operator parenthesis, but it starts in one or several characters.
//                              Default value: 1 - it is expected that a newline character
//                                                         follows the operator parenthesis of the area opening. The
//                                                         character is not to be included into the area being received.
//  ShiftEnd - Number - overrides the area end boundary when the area
//                              does not end right before the operator parenthesis, but it ends in one or several characters prior. The value
// must be negative.
//                              Default value:-1 - it is expected that a newline
//                                                         character is before the operator parenthesis of the area
//                                                         closure. The character is not to be included into the area being received.
//
Function GetMSWordTemplateArea(Val Handler,
									Val AreaName,
									Val ShiftBegin = 1,
									Val ShiftEnd = -1) Export
	
	Result = New Structure("Document,Start,End");
	
	PositionStart = ShiftBegin + GetAreaBeginPosition(Handler.COMConnection, AreaName);
	PositionEnding = ShiftEnd + GetAreaEndPosition(Handler.COMConnection, AreaName);
	
	If PositionStart >= PositionEnding Or PositionStart < 0 Then
		Return Undefined;
	EndIf;
	
	Result.Document = Handler.COMConnection.ActiveDocument;
	Result.Start = PositionStart;
	Result.End   = PositionEnding;
	
	Return Result;
	
EndFunction

// Gets a header area in the first area of the layout.
// Parameters:
// Handler - ref
// to a
// layout Return value ref to a header
//
Function GetTopFooterArea(Val Handler) Export
	
	Return New Structure("Header", Handler.COMConnection.ActiveDocument.Sections(1).Headers.Item(1));
	
EndFunction

// Gets a footer area in the first area of the layout.
// Parameters:
// Handler - ref
// to a
// layout Return value ref to a footer
//
Function GetLowerFooterArea(Handler) Export
	
	Return New Structure("Footer", Handler.COMConnection.ActiveDocument.Sections(1).Footers.Item(1));
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// The function adds areas to the print form.

// Start: function to work with MS Word headers and footers.

// Adds a footer to a print form from the layout.
// Parameters:
// PrintForm - reference to print form.
// AreaHandler - area ref in the layout.
// Parameters - list of parameters to be replaced with values.
// ObjectData - object data to fill out.
//
Procedure AddFooter(Val PrintForm, Val AreaHandler) Export
	
	AreaHandler.Footer.Range.Copy();
	Footer(PrintForm).Paste();
	
EndProcedure

// Adds a header to a print form from the layout.
// Parameters:
// PrintForm - reference to print form.
// AreaHandler - area ref in the layout.
// Parameters - list of parameters to be replaced with values.
// ObjectData - object data to fill out.
//
Procedure FillFooterParameters(Val PrintForm, Val ObjectData = Undefined) Export
	
	If ObjectData = Undefined Then
		Return;
	EndIf;
	
	For Each ParameterValue IN ObjectData Do
		If TypeOf(ParameterValue.Value) <> Type("Array") Then
			Replace(Footer(PrintForm), ParameterValue.Key, ParameterValue.Value);
		EndIf;
	EndDo;
	
EndProcedure

Function Footer(PrintForm)
	Return PrintForm.COMConnection.ActiveDocument.Sections(1).Footers.Item(1).Range;
EndFunction

// Adds a header to a print form from the layout.
// Parameters:
// PrintForm - reference to print form.
// AreaHandler - area ref in the layout.
// Parameters - list of parameters to be replaced with values.
// ObjectData - object data to fill out.
//
Procedure AddHeader(Val PrintForm, Val AreaHandler) Export
	
	AreaHandler.Header.Range.Copy();
	Header(PrintForm).Paste();
	
EndProcedure

// Adds a header to a print form from the layout.
// Parameters:
// PrintForm - reference to print form.
// AreaHandler - area ref in the layout.
// Parameters - list of parameters to be replaced with values.
// ObjectData - object data to fill out.
//
Procedure FillHeaderParameters(Val PrintForm, Val ObjectData = Undefined) Export
	
	If ObjectData = Undefined Then
		Return;
	EndIf;
	
	For Each ParameterValue IN ObjectData Do
		If TypeOf(ParameterValue.Value) <> Type("Array") Then
			Replace(Header(PrintForm), ParameterValue.Key, ParameterValue.Value);
		EndIf;
	EndDo;
	
EndProcedure

Function Header(PrintForm)
	Return PrintForm.COMConnection.ActiveDocument.Sections(1).Headers.Item(1).Range;
EndFunction

// End: functions to work with MS Word document headers and footers.

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
Function JoinArea(Val PrintForm,
							Val AreaHandler,
							Val TransitionToNextString = True,
							Val JoinTableString = False) Export
	
	AreaHandler.Document.Range(AreaHandler.Start, AreaHandler.End).Copy();
	
	PF_ActiveDocument = PrintForm.COMConnection.ActiveDocument;
	PositionEndDocument	= PF_ActiveDocument.Range().End;
	InsertArea				= PF_ActiveDocument.Range(PositionEndDocument-1, PositionEndDocument-1);
	
	If JoinTableString Then
		InsertArea.PasteAppendTable();
	Else
		InsertArea.Paste();
	EndIf;
	
	// Return boundaries of the inserted area.
	Result = New Structure("Document, Start, End",
							PF_ActiveDocument,
							PositionEndDocument-1,
							PF_ActiveDocument.Range().End-1);
	
	If TransitionToNextString Then
		InsertBreakAtNewLine(PrintForm);
	EndIf;
	
	Return Result;
	
EndFunction

// Adds a list area to the print form from the
// layout replacing the parameters in the area with values from object data.
// It is applied when the list data is displayed (bulleted or numbered list).
//
// Parameters:
// PrintFormArea - ref to an area in the print form.
// ObjectData - ObjectData
//
Procedure FillParameters(Val PrintFormArea, Val ObjectData = Undefined) Export
	
	If ObjectData = Undefined Then
		Return;
	EndIf;
	
	For Each ParameterValue IN ObjectData Do
		If TypeOf(ParameterValue.Value) <> Type("Array") Then
			Replace(PrintFormArea.Document.Content, ParameterValue.Key, ParameterValue.Value);
		EndIf;
	EndDo;
	
EndProcedure

// Start: work with collections.

// Adds a list area to the print form from the
// layout replacing the parameters in the area with values from object data.
// It is applied when the list data is displayed (bulleted or numbered list).
//
// Parameters:
// PrintForm - reference to print form.
// AreaHandler - area ref in the layout.
// Parameters - String, parameters to be replaced.
// ObjectData - ObjectData
// TransitionToNextString - Boolean, whether it is required to insert break after area output.
//
Procedure JoinAndFillSet(Val PrintForm,
									  Val AreaHandler,
									  Val ObjectData = Undefined,
									  Val TransitionToNextString = True) Export
	
	AreaHandler.Document.Range(AreaHandler.Start, AreaHandler.End).Copy();
	
	ActiveDocument = PrintForm.COMConnection.ActiveDocument;
	
	If ObjectData <> Undefined Then
		For Each RowData IN ObjectData Do
			InsertPosition = ActiveDocument.Range().End;
			InsertArea = ActiveDocument.Range(InsertPosition-1, InsertPosition-1);
			InsertArea.Paste();
			
			If TypeOf(RowData) = Type("Structure") Then
				For Each ParameterValue IN RowData Do
					Replace(ActiveDocument.Content, ParameterValue.Key, ParameterValue.Value);
				EndDo;
			EndIf;
		EndDo;
	EndIf;
	
	If TransitionToNextString Then
		InsertBreakAtNewLine(PrintForm);
	EndIf;
	
EndProcedure

// Adds a list area to the print form from the
// layout replacing the parameters in the area with values from object data.
// It is applied when a table row is displayed.
//
// Parameters:
// PrintForm - reference to print form.
// AreaHandler - area ref in the layout.
// TableName - table name (to access data).
// ObjectData - ObjectData
// TransitionToNextString - Boolean, whether it is required to insert break after area output.
//
Procedure JoinAndFillTableArea(Val PrintForm,
												Val AreaHandler,
												Val ObjectData = Undefined,
												Val TransitionToNextString = True) Export
	
	If ObjectData = Undefined Or ObjectData.Count() = 0 Then
		Return;
	EndIf;
	
	FirstRow = True;
	
	AreaHandler.Document.Range(AreaHandler.Start, AreaHandler.End).Copy();
	
	ActiveDocument = PrintForm.COMConnection.ActiveDocument;
	
	// Insert the first row using
	// which new formatted rows will be inserted.
	InsertBreakAtNewLine(PrintForm); 
	InsertPosition = ActiveDocument.Range().End;
	InsertArea = ActiveDocument.Range(InsertPosition-1, InsertPosition-1);
	InsertArea.Paste();
	ActiveDocument.Range(InsertPosition-2, InsertPosition-2).Delete();
	
	If TypeOf(ObjectData[0]) = Type("Structure") Then
		For Each ParameterValue IN ObjectData[0] Do
			Replace(ActiveDocument.Content, ParameterValue.Key, ParameterValue.Value);
		EndDo;
	EndIf;
	
	For Each TableRowData IN ObjectData Do
		If FirstRow Then
			FirstRow = False;
			Continue;
		EndIf;
		
		NewInsertPosition = ActiveDocument.Range().End;
		ActiveDocument.Range(InsertPosition-1, ActiveDocument.Range().End-1).Select();
		PrintForm.COMConnection.Selection.InsertRowsBelow();
		
		ActiveDocument.Range(NewInsertPosition-1, ActiveDocument.Range().End-2).Select();
		PrintForm.COMConnection.Selection.Paste();
		InsertPosition = NewInsertPosition;
		
		If TypeOf(TableRowData) = Type("Structure") Then
			For Each ParameterValue IN TableRowData Do
				Replace(ActiveDocument.Content, ParameterValue.Key, ParameterValue.Value);
			EndDo;
		EndIf;
		
	EndDo;
	
	If TransitionToNextString Then
		InsertBreakAtNewLine(PrintForm);
	EndIf;
	
EndProcedure

// End: work with collections.

// Inserts a line break.
// Parameters:
// Handler - Ref to WS Word document in which it is required to insert a line break.
//
Procedure InsertBreakAtNewLine(Val Handler) Export
	ActiveDocument = Handler.COMConnection.ActiveDocument;
	PositionEndDocument = ActiveDocument.Range().End;
	ActiveDocument.Range(PositionEndDocument-1, PositionEndDocument-1).InsertParagraphAfter();
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Other procedures and functions.

Function GetAreaBeginPosition(Val COMConnection, Val AreaID)
	
	AreaID = "{v8 Area." + AreaID + "}";
	
	EntireDocument = COMConnection.ActiveDocument.Content;
	EntireDocument.Select();
	
	Search = COMConnection.Selection.Find;
	Search.Text = AreaID;
	Search.ClearFormatting();
	Search.Forward = True;
	Search.execute();
	
	If Search.Found Then
		Return COMConnection.Selection.End;
	EndIf;
	
	Return -1;
	
EndFunction

Function GetAreaEndPosition(Val COMConnection, Val AreaID)
	
	AreaID = "{/v8 Area." + AreaID + "}";
	
	EntireDocument = COMConnection.ActiveDocument.Content;
	EntireDocument.Select();
	
	Search = COMConnection.Selection.Find;
	Search.Text = AreaID;
	Search.ClearFormatting();
	Search.Forward = True;
	Search.execute();
	
	If Search.Found Then
		Return COMConnection.Selection.Start;
	EndIf;
	
	Return -1;

	
EndFunction

Function PageParametersSettings()
	
	SettingsArray = New Array;
	SettingsArray.Add("Orientation");
	SettingsArray.Add("TopMargin");
	SettingsArray.Add("BottomMargin");
	SettingsArray.Add("LeftMargin");
	SettingsArray.Add("RightMargin");
	SettingsArray.Add("Gutter");
	SettingsArray.Add("HeaderDistance");
	SettingsArray.Add("FooterDistance");
	SettingsArray.Add("PageWidth");
	SettingsArray.Add("PageHeight");
	SettingsArray.Add("FirstPageTray");
	SettingsArray.Add("OtherPagesTray");
	SettingsArray.Add("SectionStart");
	SettingsArray.Add("OddAndEvenPagesHeaderFooter");
	SettingsArray.Add("DifferentFirstPageHeaderFooter");
	SettingsArray.Add("VerticalAlignment");
	SettingsArray.Add("SuppressEndnotes");
	SettingsArray.Add("MirrorMargins");
	SettingsArray.Add("TwoPagesOnOne");
	SettingsArray.Add("BookFoldPrinting");
	SettingsArray.Add("BookFoldRevPrinting");
	SettingsArray.Add("BookFoldPrintingSheets");
	SettingsArray.Add("GutterPos");
	
	Return SettingsArray;
	
EndFunction

Function EventLogMonitorEvent()
	Return NStr("en='Print';ru='Печать'", CommonUseClientServer.MainLanguageCode());
EndFunction

Procedure FailedToGeneratePrintForm(ErrorInfo)
#If WebClient Then
	CorrectionText = NStr("en='Working in web client, it is required to install Internet Explorer run under the Windows operating system. See also chapter ""Configuring web browsers to work in web client"".';ru='При работе через веб требуется браузер Internet Explorer под управлением операционной системы Windows. См. также главу документации ""Настройка веб-браузеров для работы в веб-клиенте""'");
#Else		
	CorrectionText = "";	
#EndIf
	ErrorMessage = StringFunctionsClientServer.PlaceParametersIntoString(
		NStr("en='Failed to generate a print form: %1. 
		|To display print forms in the Microsoft Word format, install Microsoft Office package on your computer. %2';ru='Не удалось сформировать печатную форму: %1. 
		|Для вывода печатных форм в формате Microsoft Word требуется, чтобы на компьютере был установлен пакет Microsoft Office. %2'"),
		BriefErrorDescription(ErrorInfo), CorrectionText);
	Raise ErrorMessage;
EndProcedure

Procedure Replace(Object, Val SearchString, Val ReplacementString)
	
	SearchString = "{v8 " + SearchString + "}";
	ReplacementString = String(ReplacementString);
	
	Object.Select();
	Selection = Object.Application.Selection;
	
	FindObject = Selection.Find;
	FindObject.ClearFormatting();
	While FindObject.Execute(SearchString) Do
		If IsBlankString(ReplacementString) Then
			Selection.Delete();
		ElsIf IsTempStorageURL(ReplacementString) Then
			Selection.Delete();
			#If WebClient Then
				TempFileName = TempFilesDir() + String(New UUID) + ".tmp";
			#Else
				TempFileName = GetTempFileName("tmp");
			#EndIf
			
			FileDescriptionFulls = New Array;
			FileDescriptionFulls.Add(New TransferableFileDescription(TempFileName, ReplacementString));
			If GetFiles(FileDescriptionFulls, , TempFilesDir(), False) Then
				Selection.Range.InlineShapes.AddPicture(TempFileName);
			Else
				Selection.TypeText("");
			EndIf;
		Else
			Selection.TypeText(ReplacementString);
		EndIf;
	EndDo;
	
	Selection.Collapse();
	
EndProcedure

#EndRegion
