#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	If Parameters.Property("Title") Then
		AutoTitle = False;
		Title = Parameters.Title;
	EndIf;
	
	Parameters.Property("DocumentsTable", DocumentsTable);
	Parameters.Property("Subject", Subject);
	
	// Casting names: the uniqueness of files + replacing invalid characters.
	UsedDocumentsNames = New Array;
	For Each ItemOfList IN DocumentsTable Do
		Presentation = TrimAll(CommonUseClientServer.ReplaceProhibitedCharsInFileName(ItemOfList.Presentation));
		Number = 0;
		While UsedDocumentsNames.Find(PresentationWithNumber(Presentation, Number)) <> Undefined Do
			Number = Number + 1;
		EndDo;
		ItemOfList.Presentation = PresentationWithNumber(Presentation, Number);
		UsedDocumentsNames.Add(ItemOfList.Presentation);
	EndDo;
	
	FillTableOfFormats();
	
	For Each SavingFormat IN FormatsTable Do
		SavingFormats.Add(SavingFormat.SpreadsheetDocumentFileType, SavingFormat.Presentation, False, SavingFormat.Picture);
	EndDo;
	SavingFormats[0].Check = True;
	
EndProcedure

&AtServer
Procedure BeforeImportDataFromSettingsAtServer(Settings)
	SavingFromSettingsFormats = Settings["SavingFormats"];
	If SavingFromSettingsFormats <> Undefined Then
		For Each SelectedFormat IN SavingFormats Do 
			FormatFromSettings = SavingFromSettingsFormats.FindByValue(SelectedFormat.Value);
			If FormatFromSettings <> Undefined Then
				SelectedFormat.Check = FormatFromSettings.Check;
			EndIf;
		EndDo;
		Settings.Delete("SavingFormats");
	EndIf;
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure Attach(Command)
	
	SelectedSavingFormats = New Array;
	
	For Each SelectedFormat IN SavingFormats Do
		If SelectedFormat.Check Then
			SelectedSavingFormats.Add(SelectedFormat.Value);
		EndIf;
	EndDo;
	
	If SelectedSavingFormats.Count() = 0 Then
		ShowMessageBox(, NStr("en = 'It is necessary to specify at least one of the offered formats.'"));
		Return;
	EndIf;
	
	SendingParameters = New Structure;
	SendingParameters.Insert("Subject", Subject);
	SendingParameters.Insert("Attachments", PlaceSpreadsheetDocumentsToTemporaryStorage(SelectedSavingFormats));
	SendingParameters.Insert("DeleteFilesAfterSend", True);
	
	Close(True);
	
	EmailOperationsClient.CreateNewEmail(SendingParameters);
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServer
Procedure FillTableOfFormats()
	
	AttributesToAdd = New Array;
	AttributesToAdd.Add(New FormAttribute("SpreadsheetDocumentFileType", New TypeDescription(), "FormatsTable"));
	AttributesToAdd.Add(New FormAttribute("Ref", New TypeDescription(), "FormatsTable"));
	AttributesToAdd.Add(New FormAttribute("Presentation", New TypeDescription(), "FormatsTable"));
	AttributesToAdd.Add(New FormAttribute("Extension", New TypeDescription(), "FormatsTable"));
	AttributesToAdd.Add(New FormAttribute("Picture", New TypeDescription(), "FormatsTable"));
	ChangeAttributes(AttributesToAdd, New Array);
	
	// Document PDF (.pdf)
	NewFormat = FormatsTable.Add();
	NewFormat.SpreadsheetDocumentFileType = SpreadsheetDocumentFileType.PDF;
	NewFormat.Ref = Enums.SaveReportFormats.PDF;
	NewFormat.Extension = "pdf";
	NewFormat.Picture = PictureLib.PDFFormat;
	
	// Microsoft Excel Sheet 2007 (.xls)
	NewFormat = FormatsTable.Add();
	NewFormat.SpreadsheetDocumentFileType = SpreadsheetDocumentFileType.XLSX;
	NewFormat.Ref = Enums.SaveReportFormats.XLSX;
	NewFormat.Extension = "xlsx";
	NewFormat.Picture = PictureLib.MSExcel2007Format;

	// Microsoft Excel Sheet 97-2003 (.xls)
	NewFormat = FormatsTable.Add();
	NewFormat.SpreadsheetDocumentFileType = SpreadsheetDocumentFileType.XLS;
	NewFormat.Ref = Enums.SaveReportFormats.XLS;
	NewFormat.Extension = "xls";
	NewFormat.Picture = PictureLib.MSExcelFormat;

	// Spreadsheet document OpenDocument (.ods).
	NewFormat = FormatsTable.Add();
	NewFormat.SpreadsheetDocumentFileType = SpreadsheetDocumentFileType.ODS;
	NewFormat.Ref = Enums.SaveReportFormats.ODS;
	NewFormat.Extension = "ods";
	NewFormat.Picture = PictureLib.OpenOfficeCalcFormat;
	
	// Tabular document (.mxl)
	NewFormat = FormatsTable.Add();
	NewFormat.SpreadsheetDocumentFileType = SpreadsheetDocumentFileType.MXL;
	NewFormat.Ref = Enums.SaveReportFormats.MXL;
	NewFormat.Extension = "mxl";
	NewFormat.Picture = PictureLib.MXLFormat;

	// Word document 2007 (.docx)
	NewFormat = FormatsTable.Add();
	NewFormat.SpreadsheetDocumentFileType = SpreadsheetDocumentFileType.DOCX;
	NewFormat.Ref = Enums.SaveReportFormats.DOCX;
	NewFormat.Extension = "docx";
	NewFormat.Picture = PictureLib.MSWord2007Format;
	
	// Web-page (.html)
	NewFormat = FormatsTable.Add();
	NewFormat.SpreadsheetDocumentFileType = SpreadsheetDocumentFileType.HTML;
	NewFormat.Ref = Enums.SaveReportFormats.HTML;
	NewFormat.Extension = "html";
	NewFormat.Picture = PictureLib.HTMLFormat;
	
	// Text document UTF8 (.txt).
	NewFormat = FormatsTable.Add();
	NewFormat.SpreadsheetDocumentFileType = SpreadsheetDocumentFileType.TXT;
	NewFormat.Ref = Enums.SaveReportFormats.TXT;
	NewFormat.Extension = "txt";
	NewFormat.Picture = PictureLib.TXTFormat;
	
	// Text document ANSI (.txt).
	NewFormat = FormatsTable.Add();
	NewFormat.SpreadsheetDocumentFileType = SpreadsheetDocumentFileType.ANSITXT;
	NewFormat.Ref = Enums.SaveReportFormats.ANSITXT;
	NewFormat.Extension = "txt";
	NewFormat.Picture = PictureLib.TXTFormat;

	// Additional formats / changing of the current list.
	For Each SavingFormat IN FormatsTable Do
		SavingFormat.Presentation = String(SavingFormat.Ref);
	EndDo;
	
EndProcedure

&AtServer
Function PresentationWithNumber(Presentation, Number)
	Return Presentation + ?(Number = 0, "", " " + Format(Number, "NG="));
EndFunction

&AtServer
Function PlaceSpreadsheetDocumentsToTemporaryStorage(SelectedSavingFormats)
	Result = New ValueList;
	
	// archive
	If PackIntoArchive Then
		ArchiveName = GetTempFileName("zip");
		ZipFileWriter = New ZipFileWriter(ArchiveName);
	EndIf;
	
	// Temporary files directory
	TempFolderName = GetTempFileName();
	CreateDirectory(TempFolderName);
	FullPathToFile = CommonUseClientServer.AddFinalPathSeparator(TempFolderName);
	
	// Saving the spreadsheet documents.
	For Each SpreadsheetDocument IN DocumentsTable Do
		
		If SpreadsheetDocument.Value.Output = UseOutput.Disable Then
			Continue;
		EndIf;
		
		For Each FileType IN SelectedSavingFormats Do
			FormatParameters = FormatsTable.FindRows(New Structure("SpreadsheetDocumentFileType", FileType))[0];
			
			FileName = SpreadsheetDocument.Presentation + "." + FormatParameters.Extension;
			FullFileName = FullPathToFile + FileName;
			
			SpreadsheetDocument.Value.Write(FullFileName, FileType);
			
			If FileType = SpreadsheetDocumentFileType.HTML Then
				InsertImagesToHTML(FullFileName);
			EndIf;
			
			If PackIntoArchive Then 
				ZipFileWriter.Add(FullFileName);
			Else
				Result.Add(PutToTempStorage(New BinaryData(FullFileName), UUID), FileName);
			EndIf;
		EndDo;
		
	EndDo;
	
	// If the archive is prepared, we record and place it into the temporary storage.
	If PackIntoArchive Then 
		ZipFileWriter.Write();
		
		FileOfArchive = New File(ArchiveName);
		Result.Add(PutToTempStorage(New BinaryData(ArchiveName), UUID), FileOfArchive.Name);
		
		DeleteFiles(ArchiveName);
	EndIf;
	
	DeleteFiles(TempFolderName);
	
	Return Result;
	
EndFunction

&AtServerNoContext
Procedure InsertImagesToHTML(HTMLFileName)
	
	TextDocument = New TextDocument();
	TextDocument.Read(HTMLFileName, TextEncoding.UTF8);
	HTMLText = TextDocument.GetText();
	
	HTMLFile = New File(HTMLFileName);
	
	ImagesFolderName = HTMLFile.BaseName + "_files";
	PathToImagesFolder = StrReplace(HTMLFile.FullName, HTMLFile.Name, ImagesFolderName);
	
	// It is expected that the folder will contain only images.
	ImageFiles = FindFiles(PathToImagesFolder, "*");
	
	For Each PictureFile IN ImageFiles Do
		ImageAsText = Base64String(New BinaryData(PictureFile.FullName));
		ImageAsText = "data:image/" + Mid(PictureFile.Extension,2) + ";base64," + Chars.LF + ImageAsText;
		
		HTMLText = StrReplace(HTMLText, ImagesFolderName + "\" + PictureFile.Name, ImageAsText);
	EndDo;
		
	TextDocument.SetText(HTMLText);
	TextDocument.Write(HTMLFileName, TextEncoding.UTF8);
	
EndProcedure

#EndRegion



// Rise { Popov N 2016-05-25
&AtClient
Function RiseGetFormInterfaceClient() Export
	Return RiseGetFormInterface();
EndFunction

&AtServer
Function RiseGetFormInterface()
	Return RiseTranslation.GetFormInterface(ThisForm);
EndFunction
// Rise } Popov N 2016-05-25
