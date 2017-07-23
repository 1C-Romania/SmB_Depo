
Function SpreadsheetDocumentToFormat(SpreadsheetDocument, Val FileName, Val FileType)
	
	Try
		SpreadsheetDocument.Write(FileName, FileType);
	Except
		Return Undefined;
	EndTry;	
	
	Return FileName;
	
EndFunction	

Function SpreadsheetDocumentToXLS(SpreadsheetDocument, Val FileInXLSFormat) Export
	
	Return SpreadsheetDocumentToFormat(SpreadsheetDocument,FileInXLSFormat,SpreadsheetDocumentFileType.XLSX);
		
EndFunction	

Function SpreadsheetDocumentToPDF(SpreadsheetDocument, Val FileInPDFFormat) Export
	
	Return SpreadsheetDocumentToFormat(SpreadsheetDocument,FileInPDFFormat,SpreadsheetDocumentFileType.PDF);
	
EndFunction	

Function SpreadsheetDocumentToTXT(SpreadsheetDocument, Val FileInTXTFormat) Export
	
	If TypeOf(SpreadsheetDocument) = Type("SpreadsheetDocument") Then
		Return SpreadsheetDocumentToFormat(SpreadsheetDocument,FileInTXTFormat,SpreadsheetDocumentFileType.TXT);
	Else
		Try
			SpreadsheetDocument.Write(FileInTXTFormat);
		Except
			Return Undefined;
		EndTry;	
	EndIf;
	
	Return FileInTXTFormat;
	
EndFunction	

Function GetPrintout(Val ObjectRef, Description, Copies = 0, Company = Undefined, Partner = Undefined, PrintMode, GeneralPrintoutForm,ReturnSpreadsheetOrArray=Undefined, FolderToSave = "", TypeOfFile = "") Export
	
	//  TODO   Jack0999   get out this PrintOut 
	
	//If Company = Undefined Then
	//	Company = Catalogs.Companies.EmptyRef();
	//EndIf;
	//
	//Result = GetPrintoutSearchResult(Description, ObjectRef, Company, Partner);
	//If Result.IsEmpty() Then
	//	
	//	If TypeOf(ObjectRef) = TypeOf(Documents.SalesInvoice.EmptyRef())
	//		AND ObjectRef.ImmediateStockMovements Then
	//		
	//		SalesDeliveryRef = InventoryTransaction.GetImmediateStockMovementsOnSalesInvoice(ObjectRef);
	//		Result = GetPrintoutSearchResult(Description, SalesDeliveryRef, Company, Partner);
	//		
	//		If Result.IsEmpty() OR SalesDeliveryRef.IsEmpty() Then
	//			
	//			Alerts.AddAlert(Alerts.ParametrizeString(Nstr("en = 'Printout %P1 was not found for %P2 (Company: %P3, Partner: %P4)'; pl = 'Wydruk %P1 nie został odnaleziony dla %P2 (Firma: %P3, Kontrahent: %P4)'"),New Structure("P1, P2, P3, P4",Description, ObjectRef,Company,Partner)),Enums.AlertType.Error,,ObjectRef);
	//			Return False;		
	//			
	//		Else
	//			
	//			 ObjectRef = SalesDeliveryRef;
	//			
	//		EndIf;	
	//		
	//	ElsIf TypeOf(ObjectRef) = TypeOf(Documents.SalesCreditNoteReturn.EmptyRef())
	//		AND ObjectRef.ImmediateStockMovements Then
	//		
	//		SalesReturnReceiptRef = InventoryTransaction.GetImmediateStockMovementsOnSalesCreditNoteReturn(ObjectRef);
	//		Result = GetPrintoutSearchResult(Description, SalesReturnReceiptRef, Company, Partner);
	//		
	//		If Result.IsEmpty() OR SalesReturnReceiptRef.IsEmpty() Then
	//			
	//			Alerts.AddAlert(Alerts.ParametrizeString(Nstr("en = 'Printout %P1 was not found for %P2 (Company: %P3, Partner: %P4)'; pl = 'Wydruk %P1 nie został odnaleziony dla %P2 (Firma: %P3, Kontrahent: %P4)'"),New Structure("P1, P2, P3, P4",Description, ObjectRef,Company,Partner)),Enums.AlertType.Error,,ObjectRef);
	//			Return False;		
	//			
	//		Else
	//			
	//			ObjectRef = SalesReturnReceiptRef;
	//			
	//		EndIf;
	//		
	//	Else
	//		
	//		Alerts.AddAlert(Alerts.ParametrizeString(Nstr("en = 'Printout %P1 was not found for %P2 (Company: %P3, Partner: %P4)'; pl = 'Wydruk %P1 nie został odnaleziony dla %P2 (Firma: %P3, Kontrahent: %P4)'"),New Structure("P1, P2, P3, P4",Description, ObjectRef,Company,Partner)),Enums.AlertType.Error,,ObjectRef);
	//		Return False;		
	//		
	//	EndIf;	
	//	
	//EndIf;
	//
	//Selection = Result.Choose();
	//Selection.Next();
	//
	//DataProcessor = GetPrintoutDataProcessor(Selection.Internal, Selection.FileName, Selection.Template);
	//
	//If DataProcessor = Undefined Then
	//	Alerts.AddAlert(Alerts.ParametrizeString(Nstr("en = 'Printout %P1 was not found for %P2 (Company: %P3, Partner: %P4)'; pl = 'Wydruk %P1 nie został odnaleziony dla %P2 (Firma: %P3, Kontrahent: %P4)'"),New Structure("P1, P2, P3, P4",Description, ObjectRef,Company,Partner)),Enums.AlertType.Error,,ObjectRef);
	//	Return False;
	//EndIf;
	//
	//DataProcessor.ObjectRef  = ObjectRef;
	//
	//Parameters = DataProcessor.Parameters;
	//If Parameters.Columns.Count() = 0 Then
	//	Parameters = GetPrintingParametersTable();
	//EndIf;
	//
	//SavedParametersStructure = Selection.SavedParameters.Get();
	//If TypeOf(SavedParametersStructure) = Type("Structure") Then
	//	
	//	For Each ParametersRow In Parameters Do
	//		
	//		SavedParameterValue = Undefined;
	//		If SavedParametersStructure.Property(ParametersRow.Name, SavedParameterValue) Then
	//			ParametersRow.Value = SavedParameterValue;
	//		EndIf;
	//		
	//	EndDo;
	//	
	//EndIf;
	//
	//NumberOfCopies = ?(Copies = 0, Selection.Copies, Copies);
	//
	//NewParameter = Parameters.Add();
	//NewParameter.Name = "COPIES";
	//NewParameter.Value = NumberOfCopies;
	//
	//DataProcessor.Parameters = Parameters;
	//
	//Spreadsheet = DataProcessor.Print();
	//
	//If CommonAtServer.IsDocumentAttribute("IsFiscalPrintOut", DataProcessor.Metadata()) Then
	//	Return True;
	//EndIf;
	//
	//PrintoutLanguage = GetPrintingParameter(Parameters, "PrintoutLanguage", Common.GetDefaultLanguageCodeAndDescription().LanguageCode);
	//PageCaption = Description + " (" + NumberOfCopies +  ")";
	//
	//If PrintMode = Enums.PrintMode.Spreadsheet Then
	//	ReturnSpreadsheetOrArray = New SpreadsheetDocument;
	//ElsIf PrintMode = Enums.PrintMode.SpreadsheetsArray Then
	//	ReturnSpreadsheetOrArray = New Array;
	//Else
	//	ReturnSpreadsheetOrArray = Undefined;
	//EndIf;
	//
	//If TypeOf(Spreadsheet) = Type("TextDocument") Then
	//	CurReturnSpreadsheet = PrintSpreadsheet(Spreadsheet, GeneralPrintoutForm, PrintMode, PageCaption, NumberOfCopies, PrintoutLanguage, FolderToSave, TypeOfFile);
	//	//CurReturnSpreadsheet.Show("Text document");
	//ElsIf TypeOf(Spreadsheet) = Type("SpreadsheetDocument") Then
	//	CurReturnSpreadsheet = PrintSpreadsheet(Spreadsheet, GeneralPrintoutForm, PrintMode, PageCaption, NumberOfCopies, PrintoutLanguage, FolderToSave, TypeOfFile);
	//	If PrintMode = Enums.PrintMode.Spreadsheet Then
	//		ReturnSpreadsheetOrArray = SpreadsheetConcat(ReturnSpreadsheetOrArray,CurReturnSpreadsheet);
	//	ElsIf PrintMode = Enums.PrintMode.SpreadsheetsArray Then
	//		ReturnSpreadsheetOrArray.Add(CurReturnSpreadsheet);
	//	EndIf;	
	//ElsIf TypeOf(Spreadsheet) = Type("Array") Then
	//	For Each ArrayElement In Spreadsheet Do
	//		CurReturnSpreadsheet = PrintSpreadsheet(ArrayElement,  GeneralPrintoutForm, PrintMode, PageCaption, NumberOfCopies, PrintoutLanguage, FolderToSave, TypeOfFile);
	//		If PrintMode = Enums.PrintMode.Spreadsheet Then
	//			ReturnSpreadsheetOrArray = SpreadsheetConcat(ReturnSpreadsheetOrArray,CurReturnSpreadsheet);
	//		ElsIf PrintMode = Enums.PrintMode.SpreadsheetsArray Then
	//			ReturnSpreadsheetOrArray.Add(CurReturnSpreadsheet);	
	//		EndIf;	
	//	EndDo;
	//EndIf;
	
EndFunction // GetPrintout()

Function PrintSpreadsheet(Spreadsheet, GeneralPrintoutForm, PrintMode, Caption = "", Copies = 1, PrintoutLanguage = "", FolderToSave = "", TypeOfFile = "") Export 
	
	If Spreadsheet = Undefined Then
		Return Undefined;
	EndIf;
	
	#If Client Then	
	If PrintMode = Enums.PrintMode.Form And TypeOf(Spreadsheet) = Type("TextDocument") Then
		GeneralPrintoutFormControls = GeneralPrintoutForm.Controls;
		LastNumber = GeneralPrintoutFormControls.ReportsPanel.Pages.Count();
		NewPage = GeneralPrintoutFormControls.ReportsPanel.Pages.Add("Page" + (LastNumber+1),Caption);
		GeneralPrintoutFormControls.ReportsPanel.CurrentPage = NewPage;
		
		NewTextDocumentField = GeneralPrintoutFormControls.Add(Type("TextDocumentField"),"TextDocumentField" + (LastNumber+1),True,GeneralPrintoutFormControls.ReportsPanel);
		NewTextDocumentField.Top = GeneralPrintoutFormControls.SpreadsheetDocumentField1.Top;
		NewTextDocumentField.Left = GeneralPrintoutFormControls.SpreadsheetDocumentField1.Left;
		NewTextDocumentField.Width = GeneralPrintoutFormControls.SpreadsheetDocumentField1.Width;
		NewTextDocumentField.Height = GeneralPrintoutFormControls.SpreadsheetDocumentField1.Height;
		NewTextDocumentField.SetLink(ControlEdge.Bottom,GeneralPrintoutFormControls.ReportsPanel,ControlEdge.Bottom);
		NewTextDocumentField.SetLink(ControlEdge.Right,GeneralPrintoutFormControls.ReportsPanel,ControlEdge.Right);
		
		NewTextDocumentField.SetText(Spreadsheet.getText());
		Return Spreadsheet;
	EndIf;
	#EndIf	
    If TypeOf(Spreadsheet) = Type("SpreadsheetDocument") Then
		If Not Spreadsheet.FitToPage And IsBlankString(Spreadsheet.PrinterName) Then
			Spreadsheet.FitToPage = True;
		EndIf;
		
		// Adding standart footer for printouts
		Spreadsheet.Footer.Enabled   = True;
		Spreadsheet.Footer.LeftText  = CommonAtServer.GetGeneratedByText(PrintoutLanguage);
		Spreadsheet.Footer.RightText = NStr("en = 'Page [&PageNumber] from [&PagesTotal]'; pl = 'Strona [&PageNumber] z [&PagesTotal]'; ru = 'Страница [&PageNumber] из [&PagesTotal]'", PrintoutLanguage);
		
	EndIf;
	
	If PrintMode = Enums.PrintMode.Printer Then
	#If Client Then	
		If FolderToSave = "" OR TypeOfFile = "NotSave" Then
			If TypeOf(Spreadsheet) = Type("TextDocument") Then
				Spreadsheet = TextDocumentToSpreadsheetDocument(Spreadsheet);
			EndIf;
			Spreadsheet.Copies = Copies;
			Spreadsheet.Print();
		Else
			If TypeOfFile = "TXT" Then
				SaveReportAsTXT(Spreadsheet, Caption,FolderToSave);
			ElsIf TypeOfFile = "PDF" Then
				If TypeOf(Spreadsheet) = Type("TextDocument") Then
					Spreadsheet = TextDocumentToSpreadsheetDocument(Spreadsheet);
				EndIf;
				SaveReportAsPDF(Spreadsheet, Caption, FolderToSave);
			ElsIf TypeOfFile = "XLS" OR TypeOfFile = "XLSX" Then
				If TypeOf(Spreadsheet) = Type("TextDocument") Then
					Spreadsheet = TextDocumentToSpreadsheetDocument(Spreadsheet);
				EndIf;
				SaveReportAsXLS(Spreadsheet, Caption, FolderToSave);
			EndIf;
		EndIf;
	#EndIf	
	ElsIf PrintMode = Enums.PrintMode.Spreadsheet
		Or PrintMode = Enums.PrintMode.SpreadsheetsArray Then
		
		Return Spreadsheet;
		
	#If Client Then	
	ElsIf PrintMode = Enums.PrintMode.Form Then
		
		GeneralPrintoutFormControls = GeneralPrintoutForm.Controls;
		LastNumber = GeneralPrintoutFormControls.ReportsPanel.Pages.Count();
		NewPage = GeneralPrintoutFormControls.ReportsPanel.Pages.Add("Page" + (LastNumber+1),Caption);
		GeneralPrintoutFormControls.ReportsPanel.CurrentPage = NewPage;
		NewSpreadsheetDocumentField = GeneralPrintoutFormControls.Add(Type("SpreadsheetDocumentField"),"SpreadsheetDocumentField" + (LastNumber+1),True,GeneralPrintoutFormControls.ReportsPanel);
		NewSpreadsheetDocumentField.Top = GeneralPrintoutFormControls.SpreadsheetDocumentField1.Top;
		NewSpreadsheetDocumentField.Left = GeneralPrintoutFormControls.SpreadsheetDocumentField1.Left;
		NewSpreadsheetDocumentField.Width = GeneralPrintoutFormControls.SpreadsheetDocumentField1.Width;
		NewSpreadsheetDocumentField.Height = GeneralPrintoutFormControls.SpreadsheetDocumentField1.Height;
		NewSpreadsheetDocumentField.SetLink(ControlEdge.Bottom,GeneralPrintoutFormControls.ReportsPanel,ControlEdge.Bottom);
		NewSpreadsheetDocumentField.SetLink(ControlEdge.Right,GeneralPrintoutFormControls.ReportsPanel,ControlEdge.Right);
		
		NewSpreadsheetDocumentField.PrintParametersName = Spreadsheet.PrintParametersName;
		NewSpreadsheetDocumentField.Copies              = Copies;
		NewSpreadsheetDocumentField.PageOrientation     = Spreadsheet.PageOrientation; 
		
		NewSpreadsheetDocumentField.HeaderSize          = Spreadsheet.HeaderSize;
		NewSpreadsheetDocumentField.TopMargin           = Spreadsheet.TopMargin;
		NewSpreadsheetDocumentField.FooterSize          = Spreadsheet.FooterSize;
		NewSpreadsheetDocumentField.BottomMargin        = Spreadsheet.BottomMargin;
		NewSpreadsheetDocumentField.RightMargin         = Spreadsheet.RightMargin;
		NewSpreadsheetDocumentField.LeftMargin          = Spreadsheet.LeftMargin;
		NewSpreadsheetDocumentField.FitToPage           = Spreadsheet.FitToPage;
		NewSpreadsheetDocumentField.PrinterName         = Spreadsheet.PrinterName;
		
		
		NewSpreadsheetDocumentField.RepeatOnRowPrint    = Spreadsheet.RepeatOnRowPrint;
		NewSpreadsheetDocumentField.RepeatOnColumnPrint = Spreadsheet.RepeatOnColumnPrint;

		NewSpreadsheetDocumentField.Put(Spreadsheet.GetArea());
	#EndIf	
	EndIf;
	
EndFunction // PrintSpreadsheet()

#If Client then
Function GetGeneralPrintoutForm(Object = Undefined) Export
	
	GeneralPrintoutForm = GetCommonForm("GeneralPrintoutForm",,New UUID);
	GeneralPrintoutForm.AdditionalProperties = New Structure;
	If Documents.AllRefsType().ContainsType(TypeOf(Object)) Then
		GeneralPrintoutForm.Caption = Common.GetDocumentCaption(Object);
	Else // Catalogs, Charts of characteristic types, Charts of accounts, Charts of calculation types
		GeneralPrintoutForm.Caption = Object.Metadata().Synonym;
	EndIf;	
	GeneralPrintoutForm.Protection  = Not IsInRole(Metadata.Roles.Right_General_SpreadsheetEditing);
	GeneralPrintoutForm.Object      = Object;
	Return GeneralPrintoutForm;
	
EndFunction

Function SendReportByEMail(ReportAttachmentName, ReportsMessageSubject, Report, Object = Undefined) Export
	
	ReportSendingSettings = DataProcessors.EMail.GetForm("ReportSendingSettings");
	ReportSendingSettings.AttachmentFileName = AdditionalInformationRepository.GenerateFileName(ReportAttachmentName);
	ReportSendingSettings.MessageSubject    = ReportsMessageSubject;
	ReportSendingSettings.Report            = Report;
	ReportSendingSettings.Object            = Object;
	
	
	EMailDataProcessor = ReportSendingSettings.DoModal();
	
	If EMailDataProcessor <> Undefined Then
		EMailDataProcessor.SendMessage(ReportSendingSettings.ObjectRecipients);
	EndIf; 

EndFunction	

Function SaveReportAsXLS(Report,ReportName,FolderPath = "",UseStandartOpenDialog = False) Export
	
	RealFolderPath = FolderPath;
	
	If Not AdditionalInformationRepository.IsFolderExist(RealFolderPath) Then
		RealFolderPath = "";
	EndIf;
	
	If IsBlankString(RealFolderPath) Then
		
		RealFolderPath = CommonAtServer.GetUserSettingsValue("ReportsDefaultDirectory",SessionParameters.CurrentUser);
		
		If Not AdditionalInformationRepository.IsFolderExist(RealFolderPath) Then
			RealFolderPath = "";
		EndIf;
		
	EndIf;
	
	If IsBlankString(RealFolderPath) Then
		RealFolderPath = AdditionalInformationRepository.GetDirectoryName();
	EndIf;	
	
	If CommonAtServer.GetUserSettingsValue("OnReportSavingAsFileUseDateInFileName",SessionParameters.CurrentUser) Then
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
		
		If TestFile.Exist() Then
			
			FilesOverwriteQueryForm = GetCommonForm("FilesOverwriteQueryForm");
			FilesOverwriteQueryForm.QueryText = 
			Nstr("en='On local drive already exist file';pl='Na dysku lokalnym istnieje plik'")+":
			|" + FileInXLSFormat + "
			|"+NStr("en='Overwrite existing file';pl='Nadpisać istniejący plik'")+"?";
			RewriteMode = FilesOverwriteQueryForm.DoModal();
			
			If Upper(RewriteMode) = "NO"
				OR Upper(RewriteMode) = "NOFORALL" Then
				FileInXLSFormat = RealFolderPath + "\" + AdditionalInformationRepository.GenerateFileName(ReportName +".xlsx",CurrentDate());
			ElsIf  RewriteMode = Undefined Then
				Return "";
			EndIf;
			
		EndIf;	
		
	EndIf;
	
	AltXLSName = RealFolderPath + "\" + AdditionalInformationRepository.GenerateFileName(ReportName +".xlsx",CurrentDate());
	FileInXLSFormat = SpreadsheetDocumentToXLS(Report,FileInXLSFormat);
	If FileInXLSFormat = Undefined Then
		FileInXLSFormat = SpreadsheetDocumentToXLS(Report,AltXLSName);
	EndIf;	
	
	Return FileInXLSFormat;
	
EndFunction	

Function SaveReportAsPDF(Val Report,ReportName,FolderPath = "",UseStandartOpenDialog = False,OpenFile = False,WriteStatus = False) Export
	Merge = False;
	
	RealFolderPath = FolderPath;
	
	If Not AdditionalInformationRepository.IsFolderExist(RealFolderPath) Then
		RealFolderPath = "";
	EndIf;
	
	If IsBlankString(RealFolderPath) Then
		
		RealFolderPath = CommonAtServer.GetUserSettingsValue("ReportsDefaultDirectory",SessionParameters.CurrentUser);
		
		If Not AdditionalInformationRepository.IsFolderExist(RealFolderPath) Then
			RealFolderPath = "";
		EndIf;
		
	EndIf;
	
	If IsBlankString(RealFolderPath) Then
		RealFolderPath = AdditionalInformationRepository.GetDirectoryName();
	EndIf;	
	
	If CommonAtServer.GetUserSettingsValue("OnReportSavingAsFileUseDateInFileName",SessionParameters.CurrentUser) Then
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
		
		If TestFile.Exist() Then
			
			FilesOverwriteQueryForm = GetCommonForm("FilesOverwriteQueryForm");
			FilesOverwriteQueryForm.QueryText = 
			Nstr("en='On local drive already exist file';pl='Na dysku lokalnym istnieje plik'")+":
			|" + FileInPDFFormat + "
			|"+NStr("en='Overwrite existing file';pl='Nadpisać istniejący plik'")+"?";
			RewriteMode = FilesOverwriteQueryForm.DoModal();
			
			If Upper(RewriteMode) = "NO"
				OR Upper(RewriteMode) = "NOFORALL" Then
				FileInPDFFormat = RealFolderPath + "\" + AdditionalInformationRepository.GenerateFileName(ReportName +".pdf",CurrentDate());
			ElsIf  RewriteMode = Undefined Then
				Return "";
			EndIf;
			
		EndIf;	
		
	EndIf;
	
	FileInPDFFormat = SpreadsheetDocumentToPDF(Report,FileInPDFFormat);
	
	If OpenFile AND FileInPDFFormat<>Undefined Then
		Try
			RunApp(FileInPDFFormat);
		Except
		EndTry;
	EndIf;
	
	Return FileInPDFFormat;
	
EndFunction	

#EndIf

Function GetPrintoutDataProcessor(Internal, FileName, Template = Undefined) Export
	
	If Internal Then
		
		If Metadata.DataProcessors.Find(FileName) = Undefined Then
			DataProcessor = Undefined;
		Else
			DataProcessor = DataProcessors[FileName].Create();
		EndIf;
		
	Else
		
		BinaryData = Template.Get();
		
		If TypeOf(BinaryData) <> Type("BinaryData") Then
			Return Undefined;
		EndIf;
		
		tmpFileName = GetTempFileName("epf");
		BinaryData.Write(tmpFileName);
		DataProcessor = ExternalDataProcessors.Create(tmpFileName);
		DeleteFiles(tmpFileName);
		
	EndIf;
	
	Return DataProcessor;
	
EndFunction

Function SpreadsheetConcat(Spreadsheet1, Spreadsheet2, UseCopies = True) Export
	
	ReturnSpreadsheet = New SpreadsheetDocument;
	If Spreadsheet1 <> Undefined Then
		Copies = ?(UseCopies,Spreadsheet1.Copies,1);
		Spreadsheet1Area = Spreadsheet1.GetArea();
		For i=1 to Copies Do
			ReturnSpreadsheet.Put(Spreadsheet1Area);
			ReturnSpreadsheet.PutHorizontalPageBreak();
		EndDo;	
	EndIf;
	
	If Spreadsheet2 <> Undefined Then
		Copies = ?(UseCopies,Spreadsheet2.Copies,1);
		Spreadsheet2Area = Spreadsheet2.GetArea();
		For i=1 to Copies Do
			ReturnSpreadsheet.Put(Spreadsheet2Area);
			ReturnSpreadsheet.PutHorizontalPageBreak();
		EndDo;	
	EndIf;
	
	Return ReturnSpreadsheet;
	
EndFunction	

Function GetPrintoutSearchResult(Description, Object, Company, Partner) Export
	
	Query = New Query;
	Query.Text = "SELECT TOP 1
	             |	PrintoutsSettings.Internal,
	             |	PrintoutsSettings.FileName,
	             |	PrintoutsSettings.Template,
	             |	PrintoutsSettings.Copies,
	             |	PrintoutsSettings.SavedParameters,
	             |	CASE
	             |		WHEN PrintoutsSettings.Partner = &EmptyPartner
	             |			THEN 1
	             |		ELSE 0
	             |	END AS PartnerOrder,
	             |	CASE
	             |		WHEN PrintoutsSettings.Company = &EmptyCompany
	             |			THEN 1
	             |		ELSE 0
	             |	END AS CompanyOrder,
	             |	PrintoutsSettings.Object,
	             |	PrintoutsSettings.Description,
	             |	PrintoutsSettings.Company,
	             |	PrintoutsSettings.Partner
	             |FROM
	             |	InformationRegister.PrintoutsSettings AS PrintoutsSettings
	             |WHERE
	             |	PrintoutsSettings.Object = &Object
	             |	AND PrintoutsSettings.Description = &Description
	             |	AND (PrintoutsSettings.Company = &EmptyCompany
	             |			OR PrintoutsSettings.Company = &Company)
	             |	AND (PrintoutsSettings.Partner = &EmptyPartner
	             |			OR PrintoutsSettings.Partner = &Partner)
	             |
	             |ORDER BY
	             |	PartnerOrder,
	             |	CompanyOrder";
	
	Query.SetParameter("Object",       New(TypeOf(Object)));
	Query.SetParameter("Description",  Description);
	Query.SetParameter("Company",      Company);
	Query.SetParameter("Partner",      Partner);
	Query.SetParameter("EmptyCompany", Catalogs.Companies.EmptyRef());
	Query.SetParameter("EmptyPartner", Undefined);
	
	Return Query.Execute();
	
EndFunction

Function GetPrintingParameter(Parameters, Name, DefaultValue) Export 
	
	If Parameters.Columns.Find("Name") = Undefined Then
		Return DefaultValue;
	EndIf;
	
	ParametersRow = Parameters.Find(Upper(Name), "Name");
	
	If ParametersRow = Undefined Then
		Return DefaultValue;
	Else
		Return ParametersRow.Value;
	EndIf;
	
EndFunction // GetPrintingParameter()

Procedure AddPrintingParameter(Parameters, Name, Description, Type, DefaultValue = Undefined, ValueList = Undefined) Export 
	
	If TypeOf(Parameters) <> Type("ValueTable") Or Parameters.Columns.Count() = 0 Then
		Parameters = GetPrintingParametersTable();
	EndIf;
	
	ParametersRow = Parameters.Add();
	
	ParametersRow.Value       = DefaultValue;
	ParametersRow.Description = Description;
	ParametersRow.Name        = Upper(Name);
	ParametersRow.Type        = Type;
	ParametersRow.ValueList   = ValueList;
	
EndProcedure // AddPrintingParameter()

Function GetPrintingParametersTable() Export 
	
	Parameters = New ValueTable;
	
	Parameters.Columns.Add("Value");
	Parameters.Columns.Add("Description", Common.GetStringTypeDescription(100));
	Parameters.Columns.Add("Name",        Common.GetStringTypeDescription(100));
	Parameters.Columns.Add("Type",        Common.GetTypeDescription("TypeDescription"));
	Parameters.Columns.Add("ValueList",   Common.GetTypeDescription("ValueList"));
	
	Return Parameters;
	
EndFunction // GetPrintingParametersTable()

// Function gets SpreadsheetDocument for print from external print form.
//
// Parameters
//  Ref         - Ref, for from which should be get document
//  BinaryData - BinaryData, external print form
//
// Return Value:
//   SpreadsheetDocument
//
Function PrintExternalForm(Ref, TemplateSource) Export 
	#If Client Then
	
	BinaryData = TemplateSource.RefOnExternalDataProcessor.Belonging[TemplateSource.LineNumber - 1].ExternalDataProcessorStorage.Get();
	If BinaryData = Undefined Then
		BinaryData = TemplateSource.RefOnExternalDataProcessor.ExternalDataProcessorStorage.Get();
	EndIf;
	
	If BinaryData = Undefined Then
		Return Undefined;
	EndIf;
	
	SpreadsheetDocument = Undefined;
	
	FileName = GetTempFileName("epf");
	Try
		BinaryData.Write(FileName);
		DataProcessor = ExternalDataProcessors.Create(FileName);
		DataProcessor.RefToObject = Ref;
		SpreadsheetDocument = DataProcessor.Print();
		DeleteFiles(FileName);
	Except
		ShowMessageBox(, ErrorDescription(), , Nstr("en='Could not generate an external print form!';pl='Błąd w trakcie wykonania zewnętrznego formularza wydruku!'"));
	EndTry;
	
	Return SpreadsheetDocument;

#EndIf
EndFunction

Function GetItemDescription(ItemLongDescription, ItemPartnersDescription = "", ItemLongDescriptionEN = "", ItemLongDescriptionRU = "", LanguageCode = "pl", ItemsNames = "Auto") Export
	
	If Upper(ItemsNames) = Upper("Auto") Then
		
		If Not IsBlankString(ItemPartnersDescription) Then
			Return TrimAll(ItemPartnersDescription);
		ElsIf LanguageCode = "en" And Not IsBlankString(ItemLongDescriptionEN) Then
			Return TrimAll(ItemLongDescriptionEN);
		ElsIf LanguageCode = "ru" And Not IsBlankString(ItemLongDescriptionRU) Then
			Return TrimAll(ItemLongDescriptionRU);
		Else
			Return TrimAll(ItemLongDescription);
		EndIf;
		
	ElsIf Upper(ItemsNames) = Upper("ItemDescription") Then
		
		Return TrimAll(ItemLongDescription);
		
	ElsIf Upper(ItemsNames) = Upper("ItemDescriptionEN") Then
		
		If IsBlankString(ItemLongDescriptionEN) Then
			Alerts.AddAlert(NStr("en = 'No english description for the item'; pl = 'Nie ma angielskiej nazwy dla pozycji'") + ": " + TrimAll(ItemLongDescription));
		EndIf;
		
		Return TrimAll(ItemLongDescriptionEN);
		
	ElsIf Upper(ItemsNames) = Upper("ItemDescriptionRU") Then
		
		If IsBlankString(ItemLongDescriptionRU) Then
			Alerts.AddAlert(NStr("en = 'No russian description for the item'; pl = 'Nie ma rosyjskiej nazwy dla pozycji'") + ": " + TrimAll(ItemLongDescription));
		EndIf;
		
		Return TrimAll(ItemLongDescriptionRU);
		
	ElsIf Upper(ItemsNames) = Upper("PartnersDescription") Then
		
		If IsBlankString(ItemPartnersDescription) Then
			Alerts.AddAlert(NStr("en = 'No partner''s description for the item'; pl = 'Nie ma nazwy kontrahenta dla pozycji'") + ": " + TrimAll(ItemLongDescription));
		EndIf;
		
		Return TrimAll(ItemPartnersDescription);
		
	Else
		
		Return "";
		
	EndIf;
	
EndFunction

#If Client Then
	
Function IsPrintOnPostAndClose(Object) Export
	
	If (TypeOf(Object) = Type("DocumentObject.SalesInvoice") OR TypeOf(Object) = Type("DocumentObject.SalesCreditNoteReturn"))
		AND Object.ImmediateStockMovements Then
		RestoredValue = RestoreValue("PrintSettingsImmediateStockMovements" + Object.Metadata().Name);
	Else	
		RestoredValue = RestoreValue("PrintSettings" + Object.Metadata().Name);
	EndIf;
	
	If RestoredValue = Undefined Then
		Return False;
	Else
		Return RestoredValue.PrintOnPostAndClose;
	EndIf;	
	
EndFunction	

Function CallPrintoutSettingsForm(Form,IsFullMode = False) Export
	
	If Form <> Undefined And Form.Modified Then
		
		If Documents.AllRefsType().ContainsType(TypeOf(Form.Ref)) Then
			ShowMessageBox(, NStr("en='Please, save document before printing.';pl='Zapisz dokument przed drukowaniem.'"));
		Else // Catalogs
			ShowMessageBox(, NStr("en='Please, save element before printing.';pl='Zapisz element przed drukowaniem.'"));
		EndIf;
		
		Return False;
		
	EndIf;
	ObjectRef = Form.Ref;
	Object = ObjectRef.GetObject();
	If Documents.AllRefsType().ContainsType(TypeOf(ObjectRef)) Then
		
		If ObjectRef.Metadata().Posting = Metadata.ObjectProperties.Posting.Allow Then
			If Not ObjectRef.Posted Then
				Alerts.AddAlert(NStr("en='You cannot print not posted documents.';pl='Nie można drukować dokumentów niezatwierdzonych.';ru='Нельзя распечатать непроведенные документы.'"),,,Object,Form);
				Return False;
			EndIf;
		EndIf;
		
	EndIf;

	PrintoutSettingsForm = GetCommonForm("PrintoutSettingsForm",Form,Form);
	PrintoutSettingsForm.Object = ObjectRef;
	PrintoutSettingsForm.IsFullMode = IsFullMode;
	PrintoutSettingsForm.DoModal();
	RetForm = PrintoutSettingsForm.ReturnValue;
	If RetForm <> Undefined Then
		RetForm.Open();
	EndIf;	
	
	Return True;
	
EndFunction	

Procedure SetQuickPrintHandler(Form, Handler = "PostAndPrintAndClose") Export
	
	If IsPrintOnPostAndClose(Form.DocumentObject) Then
		Form.Controls.FormMainActions.Buttons.FormMainActionsOK.Action = New Action("PostAndPrintAndClose");
	EndIf;	

EndProcedure

Procedure PerformPrintOnPostAndPrintAndClose(Form) Export
	If Form.AdditionalProperties.Property("PostAndPrintAndClose") Then
		Printouts.CallPrintoutSettingsForm(Form);
	EndIf;
EndProcedure

Function SaveReportAsTXT(Report,ReportName,FolderPath = "",UseStandartOpenDialog = False) Export
	
	RealFolderPath = FolderPath;
	
	If Not AdditionalInformationRepository.IsFolderExist(RealFolderPath) Then
		RealFolderPath = "";
	EndIf;
	
	If IsBlankString(RealFolderPath) Then
		
		RealFolderPath = CommonAtServer.GetUserSettingsValue("ReportsDefaultDirectory",SessionParameters.CurrentUser);
		
		If Not AdditionalInformationRepository.IsFolderExist(RealFolderPath) Then
			RealFolderPath = "";
		EndIf;
		
	EndIf;
	
	If IsBlankString(RealFolderPath) Then
		RealFolderPath = AdditionalInformationRepository.GetDirectoryName();
	EndIf;	
	
	If CommonAtServer.GetUserSettingsValue("OnReportSavingAsFileUseDateInFileName",SessionParameters.CurrentUser) Then
		FileInTXTFormat = RealFolderPath + "\" + AdditionalInformationRepository.GenerateFileName(ReportName +".txt",CurrentDate());
	Else	
		FileInTXTFormat = RealFolderPath + "\" + ReportName +".txt";
	EndIf;
	
	If UseStandartOpenDialog Then
		
		Mode = FileDialogMode.Save;
		SaveFileDialog = New FileDialog(Mode);
		SaveFileDialog.FullFileName = FileInTXTFormat;
		SaveFileDialog.Directory = RealFolderPath;
		SaveFileDialog.DefaultExt = "txt";
		Filter = "Text files(*.txt)|*.txt";
		SaveFileDialog.Filter = Filter;
		SaveFileDialog.CheckFileExist = True;
		SaveFileDialog.Multiselect = False;
		SaveFileDialog.Title = Nstr("en='Save report as Text file';pl='Zapisz raport jako plik Text'");
		
		If SaveFileDialog.Choose() Then
			
			FileInTXTFormat = SaveFileDialog.FullFileName;
		Else
			Return "";
		EndIf;
		
	Else	
		
		TestFile = New File(FileInTXTFormat);
		
		If TestFile.Exist() Then
			
			FilesOverwriteQueryForm = GetCommonForm("FilesOverwriteQueryForm");
			FilesOverwriteQueryForm.QueryText = 
			Nstr("en='On local drive already exist file';pl='Na dysku lokalnym istnieje plik'")+":
			|" + FileInTXTFormat + "
			|"+NStr("en='Overwrite existing file';pl='Nadpisać istniejący plik'")+"?";
			RewriteMode = FilesOverwriteQueryForm.DoModal();
			
			If Upper(RewriteMode) = "NO"
				OR Upper(RewriteMode) = "NOFORALL" Then
				FileInTXTFormat = RealFolderPath + "\" + AdditionalInformationRepository.GenerateFileName(ReportName +".txt",CurrentDate());
			ElsIf  RewriteMode = Undefined Then
				Return "";
			EndIf;
			
		EndIf;	
		
	EndIf;
	
	AltTxtFile = RealFolderPath + "\" + AdditionalInformationRepository.GenerateFileName(ReportName +".txt",CurrentDate());
	FileInTXTFormat = SpreadsheetDocumentToTXT(Report,FileInTXTFormat);
	If FileInTXTFormat = Undefined Then
		FileInTXTFormat = SpreadsheetDocumentToTXT(Report,AltTxtFile);
	EndIf;	
	
	Return FileInTXTFormat;
	
EndFunction	

Function TextDocumentToSpreadsheetDocument(TextDocument) Export
	
	If (TypeOf(TextDocument) = Type("TextDocumentField"))OR(TypeOf(TextDocument) = Type("TextDocument")) Then
		NewSpreadsheetDocument = New SpreadsheetDocument;
		CurentWidth = 9;
		For NumberLine = 1 To TextDocument.LineCount() Do
			CellArea = NewSpreadsheetDocument.Area(NumberLine, 1, NumberLine, 1);
			CellArea.TextPlacement = SpreadsheetDocumentTextPlacementType.Cut;
			CellArea.Text = TextDocument.GetLine(NumberLine);
			If StrLen(TextDocument.GetLine(NumberLine)) * 1 > CurentWidth Then
				CellArea.ColumnWidth = StrLen(TextDocument.GetLine(NumberLine)) * 1;
			EndIf;
		EndDo;
		Return NewSpreadsheetDocument;
	ElsIf (TypeOf(TextDocument) = Type("SpreadsheetDocumentField"))OR(TypeOf(TextDocument) = Type("SpreadsheetDocument")) Then
		Return TextDocument;
	Else
		Return Undefined;
	EndIf;
EndFunction	

#EndIf