
&AtServer
Function ExportToMXLAtServer()
	TempFileName = GetTempFileName("mxl");
	RiseTranslation.ExportChangesToMXL(TempFileName, ?(ExportMode = "Changes", DateFrom, Undefined), SourceLanguage, TargetLanguage);
	FileData = New BinaryData(TempFileName);
	Return PutToTempStorage(FileData, UUID);
EndFunction

&AtClient
Procedure ExportToMXL(Command)
	If IsBlankString(FileName) Then
		msg = New UserMessage();
		msg.Field = "FileName";
		msg.Text = NStr("ru = 'Не указано имя файла!'; en = 'File name is not specified!'");
		msg.Message();
	Else
		GetFile(ExportToMXLAtServer(), FileName, False);
		Status(NStr("en = 'Done'; ru = 'Выполнено'"));
	EndIf; 
EndProcedure

&AtClient
Procedure FileSelected(Result, Params) Export
	If TypeOf(Result) = Type("Array") And Result.Count() > 0 Then
		FileName = Result[0];
	EndIf; 
EndProcedure

&AtClient
Procedure ExportModeOnChange(Item)
	Items.DateFrom.ReadOnly = (ExportMode <> "Changes");
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	If ExportMode = "" Then
		ExportMode = "Changes";
	EndIf; 
	ExportModeOnChange(Undefined);
EndProcedure

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	SourceLanguage = SessionParameters.RiseSourceLanguage;
	TargetLanguage = SessionParameters.RiseTargetLanguage;
	
	For each language in Metadata.Languages Do
		Items.SourceLanguage.ChoiceList.Add(language.LanguageCode);
		Items.TargetLanguage.ChoiceList.Add(language.LanguageCode);
	EndDo;
	
EndProcedure

&AtClient
Procedure FileNameStartChoice(Item, ChoiceData, StandardProcessing)
	StandardProcessing = False;
	
	Dialog = New FileDialog(FileDialogMode.Save);
	Dialog.FullFileName = ExportMode + Title(SourceLanguage) + Title(TargetLanguage) + ?(ExportMode = "Changes", Format(DateFrom, "DF=-yyyyMMdd"), "") + ".mxl";
	Dialog.Filter = "MXL (*.mxl)|*.mxl";
	Dialog.Show(New NotifyDescription("FileSelected", ThisForm));
EndProcedure

&AtServer
Function GetSpreadsheetDocument(Address)
	TempFileName = GetTempFileName("mxl");
	TempFile = GetFromTempStorage(Address);
	TempFile.Write(TempFileName);
	SpDoc = New SpreadsheetDocument;
	SpDoc.Read(TempFileName);
	Return SpDoc;
EndFunction
	
&AtClient
Procedure FileNameOpening(Item, StandardProcessing)
	StandardProcessing = False;
	Address = "";
	BeginPutFile(New NotifyDescription("PutFileEnd", ThisForm), Address, FileName, False, UUID);
EndProcedure

&AtClient
Procedure PutFileEnd(Result, Address, FullName, Parameters) Export
	SpDoc = GetSpreadsheetDocument(Address);
	SpDoc.Show(FileName);
EndProcedure