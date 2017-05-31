Procedure CallPrintoutSettingsForm(Objects, CommandExecuteParameters, ShowSetting = False) Export
	Parameters = PrintManagerServer.GetParameters(Objects, CommandExecuteParameters.Source.FormName);
	Parameters.Insert("ShowSetting", Not Parameters.HideThisWindow Or ShowSetting);
	
	NotifyOpenPrintoutForm = New NotifyDescription("OpenPrintoutForm", PrintManagerClient);
	If Parameters.ShowSetting Then
		OpenForm("CommonForm.PrintoutSettingsFormManaged", Parameters, ,,,, NotifyOpenPrintoutForm, ?(TypeOf(CommandExecuteParameters.Source) = Type("Structure"), FormWindowOpeningMode.LockWholeInterface, FormWindowOpeningMode.LockOwnerWindow));
	Else
		OpenPrintoutForm(New Structure("PrintList, DirectPrinting, PrintFileName, InitialFormID", Parameters.PrintList, Parameters.DirectPrinting, Parameters.PrintFileName, New UUID));
	EndIf;
EndProcedure

Procedure OpenPrintoutForm(Parameters, AdditionalParameters = Undefined) Export
	If Not Parameters = Undefined Then
		OpenForm("CommonForm.GeneralPrintoutFormManaged", Parameters,,True);
	EndIf;
EndProcedure

Function SaveReportAsPDF(Val Report,ReportName,FolderPath = "",UseStandartOpenDialog = False,OpenFile = False,WriteStatus = False) Export
	Merge = False;
	
	RealFolderPath = FolderPath;
	
	If Not AdditionalInformationRepository.IsFolderExist(RealFolderPath) Then
		RealFolderPath = "";
	EndIf;
	
	If IsBlankString(RealFolderPath) Then
		
		RealFolderPath = CommonAtClient.GetUserSettingsValue("ReportsDefaultDirectory");
		
		If Not AdditionalInformationRepository.IsFolderExist(RealFolderPath) Then
			RealFolderPath = "";
		EndIf;
		
	EndIf;
	
	If IsBlankString(RealFolderPath) Then
		RealFolderPath = AdditionalInformationRepository.GetDirectoryName();
	EndIf;	
	
	If CommonAtClient.GetUserSettingsValue("OnReportSavingAsFileUseDateInFileName") Then
		FileInPDFFormat = RealFolderPath + "\" + AdditionalInformationRepository.GenerateFileName(ReportName +".pdf",CurrentDate());
	Else	
		FileInPDFFormat = RealFolderPath + "\" + ReportName +".pdf";
	EndIf;
	
	If UseStandartOpenDialog Then
		
		Mode = FileDialogMode.Save;
		SaveFileDialog = New FileDialog(Mode);
		SaveFileDialog.FullFileName = FileInPDFFormat;
		SaveFileDialog.Directory = RealFolderPath;
		SaveFileDialog.DefaultExt = "pdf";
		Filter = "PDF files(*.pdf)|*.pdf";
		SaveFileDialog.Filter = Filter;
		SaveFileDialog.CheckFileExist = True;
		SaveFileDialog.Multiselect = False;
		SaveFileDialog.Title = Nstr("en='Save report as PDF file';pl='Zapisz raport jako plik PDF'");
		
		If SaveFileDialog.Choose() Then
			
			FileInPDFFormat = SaveFileDialog.FullFileName;
		Else
			Return "";
		EndIf;
		
	Else	
		
		TestFile = New File(FileInPDFFormat);

	EndIf;
	
	FileInPDFFormat = Printouts.SpreadsheetDocumentToPDF(Report,FileInPDFFormat);
	
	If OpenFile AND FileInPDFFormat<>Undefined Then
		Try
			RunApp(FileInPDFFormat);
		Except
		EndTry;
	EndIf;
	
	Return FileInPDFFormat;
	
EndFunction	

Function SaveReportAsXLS(Report,ReportName,FolderPath = "",UseStandartOpenDialog = False, OpenFile = False) Export
	
	RealFolderPath = FolderPath;
	
	If Not AdditionalInformationRepository.IsFolderExist(RealFolderPath) Then
		RealFolderPath = "";
	EndIf;
	
	If IsBlankString(RealFolderPath) Then
		
		RealFolderPath = CommonAtClient.GetUserSettingsValue("ReportsDefaultDirectory");
		
		If Not AdditionalInformationRepository.IsFolderExist(RealFolderPath) Then
			RealFolderPath = "";
		EndIf;
		
	EndIf;
	
	If IsBlankString(RealFolderPath) Then
		RealFolderPath = AdditionalInformationRepository.GetDirectoryName();
	EndIf;	
	
	If CommonAtClient.GetUserSettingsValue("OnReportSavingAsFileUseDateInFileName") Then
		FileInXLSFormat = RealFolderPath + "\" + AdditionalInformationRepository.GenerateFileName(ReportName +".xlsx",CurrentDate());
	Else	
		FileInXLSFormat = RealFolderPath + "\" + ReportName +".xlsx";
	EndIf;
	
	If UseStandartOpenDialog Then
		
		Mode = FileDialogMode.Save;
		SaveFileDialog = New FileDialog(Mode);
		SaveFileDialog.FullFileName = FileInXLSFormat;
		SaveFileDialog.Directory = RealFolderPath;
		SaveFileDialog.DefaultExt = "xlsx";
		Filter = "Excel2007-... files (*.xlsx)|*.xlsx";
		SaveFileDialog.Filter = Filter;
		SaveFileDialog.CheckFileExist = True;
		SaveFileDialog.Multiselect = False;
		SaveFileDialog.Title = Nstr("en='Save report as Excel file';pl='Zapisz raport jako plik Excel'");
		
		If SaveFileDialog.Choose() Then
			
			FileInXLSFormat = SaveFileDialog.FullFileName;
		Else
			Return "";
		EndIf;
		
	Else	
		
		TestFile = New File(FileInXLSFormat);
		
	EndIf;
	
	AltXLSName = RealFolderPath + "\" + AdditionalInformationRepository.GenerateFileName(ReportName +".xlsx",CurrentDate());
	FileInXLSFormat = Printouts.SpreadsheetDocumentToXLS(Report,FileInXLSFormat);
	If FileInXLSFormat = Undefined Then
		FileInXLSFormat = Printouts.SpreadsheetDocumentToXLS(Report,AltXLSName);
	EndIf;	
	
	If OpenFile AND FileInXLSFormat<>Undefined Then
		Try
			RunApp(FileInXLSFormat);
		Except
		EndTry;
	EndIf;
	
	Return FileInXLSFormat;
	
EndFunction	

Function SendReportByEMail(PrintDocumentsInfo) Export

	OpenForm("DataProcessor.EMail.Form.ReportSendingSettingsManaged", New Structure("PrintDocumentsInfo", PrintDocumentsInfo));

EndFunction	

Procedure PrintBookkeepingOperation(Form) Export
	
	StructureParamentsList = (New Structure("StructureParamentsList")); 	
	
	ObjectInfo = New Structure("Posted,Ref",Form.Object.Posted,Form.Object.Ref);
	
	ObjectRefsInfo = New Array;
	ObjectRefsInfo.Add(ObjectInfo);
	
	PrintInfo = New Structure;
	PrintInfo.Insert("Internal",True);
	PrintInfo.Insert("FileName","PrintoutDocumentsBookkeepingRecords");
	PrintInfo.Insert("SavedParameters",Undefined);
	PrintInfo.Insert("Copies",1);
	PrintInfo.Insert("Company",Form.Object.Company);	
	PrintInfo.Insert("IsDocument",True);
	PrintInfo.Insert("IsFiscal",False);
	PrintInfo.Insert("ObjectRefsInfo",ObjectRefsInfo);
	PrintInfo.Insert("SavedParameters",CommonUse.ValueToValueStorage(Undefined));
			
	StructureParamentsList = New Array;
	StructureParamentsList.Add(PrintInfo);
	
	PrintoutsInfo = New Structure();
	PrintoutsInfo.Insert("Description",Form.Object.Description);  //?
	PrintoutsInfo.Insert("StructureParamentsList",StructureParamentsList);
	
	PrintList = New Array;	
	PrintList.Add(PrintoutsInfo);
	OpenForm("CommonForm.GeneralPrintoutFormManaged", New Structure("PrintList, DirectPrinting, PrintFileName, InitialFormID", PrintList, False, "PrintoutDocumentsBookkeepingRecords", Form.UUID),,True);
		         
EndProcedure             
