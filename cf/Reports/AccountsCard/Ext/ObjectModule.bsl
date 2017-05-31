Var SavedSetting Export;
Var Details Export;
Var GenerateOnOpen Export;
Var SettingsOfComposerOnOpenData Export;

Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	ReportsModulesAtServer.FillCheckProcessing(ThisObject, Cancel, CheckedAttributes);
EndProcedure

Procedure OnComposeResult(ResultDocument, DetailsData, StandardProcessing)
	
	OutputIntoReportForm = NOT SettingsComposer.Settings.AdditionalProperties.Property("SpreadsheetOutput");
	ReportsModulesAtServer.CommonComposeResult(ThisObject,ResultDocument, DetailsData, StandardProcessing, OutputIntoReportForm);
	
EndProcedure

Function GenerateReport(Result = Undefined, DetailsData = Undefined, OutputIntoReportForm = True) Export
	
	#If ThickClientOrdinaryApplication Then
	MessageText = NStr("en = 'Please input Company'; pl = 'Wypełnij pole Firma'");
	If Company.IsEmpty() Then
		#If Client Then
			DoMessageBox(MessageText);
		#Else	
			Alerts.AddAlert(MessageText);
		#EndIf	
		Return Undefined;
	EndIf;
	
	MessageText = NStr("en = 'Please input Account'; pl = 'Wypełnij pole Konto'");
	
	If Account.IsEmpty() Then
		#If Client Then
			DoMessageBox(MessageText);
		#Else	
			Alerts.AddAlert(MessageText);
		#EndIf	
		Return Undefined;
	EndIf;
	#EndIf
	
	Result.Clear();
	LanguageCode = Common.GetDefaultLanguageCodeAndDescription().LanguageCode;
	Settings = SettingsComposer.GetSettings();
	SettingsComposer.Refresh();
	
	Schema = DataCompositionSchema;
	
	//Generate data composition template using template composer
	TemplateComposer = New DataCompositionTemplateComposer;	

	NeedToResetEndOfPeriod = False;
	
	If NOT ShowClosePeriodRecords Then
		EndOfPeriod_Param = TemplateReports.SetParameter(SettingsComposer,"EndOfPeriod");
		If EndOfPeriod_Param <> Undefined AND EndOfPeriod_Param.Value <> '00010101000000' Then
			// decrement last 10 sec
			TemplateReports.SetParameter(SettingsComposer,"EndOfPeriod",EndOfDay(EndOfPeriod_Param.Value)-10);
		Else
			NeedToResetEndOfPeriod = True;
			TemplateReports.SetParameter(SettingsComposer,"EndOfPeriod",EndOfDay(CurrentDate())-10);
		EndIf;		
	Else
		
		EndOfPeriod_Param = TemplateReports.SetParameter(SettingsComposer,"EndOfPeriod");
		If EndOfPeriod_Param <> Undefined AND EndOfPeriod_Param.Value <> '00010101000000' Then
			// decrement last 10 sec
			TemplateReports.SetParameter(SettingsComposer,"EndOfPeriod",EndOfDay(EndOfPeriod_Param.Value));
		EndIf;		
		
	EndIf;	
		
	CompositionTemplate = TemplateComposer.Execute(Schema, SettingsComposer.Settings, DetailsData,,Type("DataCompositionValueCollectionTemplateGenerator"));	
	Query = New Query();
	For Each DataSet In CompositionTemplate.DataSets[0].Items Do
		If TypeOf(DataSet) = Type("DataCompositionTemplateDataSetQuery") Then
			Query.Text = Query.Text + DataSet.Query + "; ";
		EndIf;	
	EndDo;
	
	For Each Parameter In CompositionTemplate.ParameterValues Do
		If TypeOf(Parameter.Value) <> Type("DataCompositionExpression") Then
			Query.SetParameter(Parameter.Name,Parameter.Value);
		EndIf;	
	EndDo;	
	
	For Each Parameter In CompositionTemplate.ParameterValues Do
		If TypeOf(Parameter.Value) = Type("DataCompositionExpression") Then
			ValueDataCompositionExpression = StrReplace(String(Parameter.Value),"&","Query.Parameters.");
			Query.SetParameter(Parameter.Name,Eval(ValueDataCompositionExpression));
		EndIf;
	EndDo;

	If NeedToResetEndOfPeriod Then
		NeedToResetEndOfPeriod = False;
		TemplateReports.SetParameter(SettingsComposer,"EndOfPeriod",'00010101000000');
	EndIf;
	
	QueryResult = Query.ExecuteBatch();
	
	Selection = QueryResult[1].Select();
	
	OpenBalance = 0;
	OpenBalanceDr = 0;
	OpenBalanceCr = 0;
	
	While Selection.Next() Do
		OpenBalance = OpenBalance + Selection.AmountBalanceDr - Selection.AmountBalanceCr;
		OpenBalanceDr = OpenBalanceDr + Selection.AmountBalanceDr;
		OpenBalanceCr = OpenBalanceCr + Selection.AmountBalanceCr;
	EndDo;	
	
	Selection = QueryResult[2].Select();
	
	ClosingBalance = 0;
	ClosingBalanceDr = 0;
	ClosingBalanceCr = 0;
	
	While Selection.Next() Do
		ClosingBalance = ClosingBalance + Selection.AmountBalanceDr - Selection.AmountBalanceCr;
		ClosingBalanceDr = ClosingBalanceDr + Selection.AmountBalanceDr;
		ClosingBalanceCr = ClosingBalanceCr + Selection.AmountBalanceCr;
	EndDo;	
	
	GenerationDate = CurrentDate(); // fixing generation time
	VATNumberTemplatesStructure = Constants.VATNumberFormatStrings.Get().Get();
	FormattedVATNumbersMap = New Map;
		
	// Setting header, footer and page properties
	Result.FitToPage = True;
	Result.PageOrientation = PageOrientation.Portrait;
	
	Template = GetTemplate("Template");
	Template.TemplateLanguageCode = Common.GetDefaultLanguageCodeAndDescription().LanguageCode;
	
	Header = Template.GetArea("Header");
	
	RowsHeaderDescription = Template.GetArea("RowsHeader|DescriptionColumns");
	RowsHeaderAmount     = Template.GetArea("RowsHeader|AmountColumns");
	RowsHeaderTurnover       = Template.GetArea("RowsHeader|TurnoverColumns");
	
	If Account.Currency Then
		RowDescription = Template.GetArea("RowWithCurrency|RowDescriptionColumns");
		RowAmount     = Template.GetArea("RowWithCurrency|RowAmountColumns");
		RowTurnover       = Template.GetArea("RowWithCurrency|RowTurnoverColumns");
	Else
		RowDescription = Template.GetArea("Row|RowDescriptionColumns");
		RowAmount     = Template.GetArea("Row|RowAmountColumns");
		RowTurnover       = Template.GetArea("Row|RowTurnoverColumns");
	EndIf;	
	
	TotalsDescription = Template.GetArea("Totals|DescriptionColumns");
	TotalsAmount     = Template.GetArea("Totals|AmountColumns");
	TotalsTurnover       = Template.GetArea("Totals|TurnoverColumns");
	
	TotalsBriefDescription = Template.GetArea("TotalsBrief|DescriptionColumns");
	TotalsBriefAmount     = Template.GetArea("TotalsBrief|AmountColumns");
	TotalsBriefTurnover       = Template.GetArea("TotalsBrief|TurnoverColumns");
	
	RowAmount.Area(1, 1, RowAmount.TableHeight, RowAmount.TableWidth).MarkNegatives = NegativeInRed;
	RowTurnover.Area(1, 1, RowTurnover.TableHeight, RowTurnover.TableWidth).MarkNegatives = NegativeInRed;
	TotalsAmount.Area(1, 1, TotalsAmount.TableHeight, TotalsAmount.TableWidth).MarkNegatives = NegativeInRed;
	TotalsTurnover.Area(1, 1, TotalsTurnover.TableHeight, TotalsTurnover.TableWidth).MarkNegatives = NegativeInRed;
	TotalsBriefAmount.Area(1, 1, TotalsBriefAmount.TableHeight, TotalsBriefAmount.TableWidth).MarkNegatives = NegativeInRed;
	TotalsBriefTurnover.Area(1, 1, TotalsBriefTurnover.TableHeight, TotalsBriefTurnover.TableWidth).MarkNegatives = NegativeInRed;	
	
	Header.Parameters.Account = Account;
	Header.Parameters.Company = Common.GetLongDescription(Company);
	Header.Parameters.Address = InformationRegisters.ContactInformation.Get(New Structure("Object, ContactInformationType, ContactInformationProfile", Company, Enums.ContactInformationTypes.Address, Catalogs.ContactInformationProfiles.CompanyLegalAddress)).Description;
	Header.Parameters.VATNumber     = Taxes.GetVATNumberPresentationWithCash(Company.VATNumber, VATNumberTemplatesStructure, FormattedVATNumbersMap);
	Header.Parameters.Period  = TemplateReports.GetReportPeriodDescription(SettingsComposer,LanguageCode);
	Header.Parameters.Filters   = String(SettingsComposer.Settings.Filter);
	
	NumberOfExtDimension = Account.ExtDimensionTypes.Count();
	
	If NumberOfExtDimension = 1 Then
		RowsHeaderDescription.Parameters.ExtDimensionType1 = Account.ExtDimensionTypes[0].ExtDimensionType;
	ElsIf NumberOfExtDimension = 2 Then
		RowsHeaderDescription.Parameters.ExtDimensionType1 = Account.ExtDimensionTypes[0].ExtDimensionType;
		RowsHeaderDescription.Parameters.ExtDimensionType2 = Account.ExtDimensionTypes[1].ExtDimensionType;
	ElsIf NumberOfExtDimension = 3 Then
		RowsHeaderDescription.Parameters.ExtDimensionType1 = Account.ExtDimensionTypes[0].ExtDimensionType;
		RowsHeaderDescription.Parameters.ExtDimensionType2 = Account.ExtDimensionTypes[1].ExtDimensionType;
		RowsHeaderDescription.Parameters.ExtDimensionType3 = Account.ExtDimensionTypes[2].ExtDimensionType;
	EndIf;
	
	RowsHeaderAmount.Parameters.AmountDr = Format(OpenBalanceDr,"ND=15; NFD=2");
	RowsHeaderAmount.Parameters.AmountCr = Format(OpenBalanceCr,"ND=15; NFD=2");
	
	Result.Put(Header);
	Result.Put(RowsHeaderDescription);
	Result.Join(RowsHeaderAmount);
	Result.Join(RowsHeaderTurnover);
	
	Result.RepeatOnRowPrint= Result.Area(1,1,Result.TableHeight,Result.TableWidth);
	
	Result.FixedTop = Header.TableHeight + RowsHeaderDescription.TableHeight;
	Result.FixedLeft = 5;
	
	ColumnsNumber = 7;	
	
	Result.RepeatOnRowPrint = Result.Area(Result.TableHeight - 2, , Result.TableHeight);	
	
	RowCount = 1;
	
	TotalDr = 0;
	TotalCr = 0;
	CurBalance = OpenBalanceDr - OpenBalanceCr;
	
	TotalDrOnPage = 0;
	TotalCrOnPage = 0;
	
	TotalDrOnPrevPage = 0;
	TotalCrOnPrevPage = 0;
	
	Selection = QueryResult[0].Select();
	While Selection.Next() Do
		
		#If Client Then
		UserInterruptProcessing();
		#EndIf
	
		RowDescription.Parameters.Number = RowCount;
		RowDescription.Parameters.Date = Selection.Period;
		RowDescription.Parameters.Document = Selection.Recorder;
		RowDescription.Parameters.SourceDocument = "";
		If Documents.AllRefsType().ContainsType(TypeOf(Selection.InitialDocumentNumber)) Then
			RowDescription.Parameters.SourceDocument = Selection.InitialDocumentNumber;
		Else
			
			SourceDocumentDescr = "";
			If Not IsBlankString(TrimAll(Selection.InitialDocumentNumber)) Then
				SourceDocumentDescr = TrimAll(Selection.InitialDocumentNumber);
				If Selection.InitialDocumentDate <> '00010101000000'Then
					SourceDocumentDescr = SourceDocumentDescr + " "+ Nstr("en='from';pl='z dnia'") + " " + Format(Selection.InitialDocumentDate,"DLF=D");
				EndIf;	
			EndIf;	
			
			If Not IsBlankString(SourceDocumentDescr) Then
				RowDescription.Parameters.SourceDocument = SourceDocumentDescr;
			EndIf;	
			
		EndIf;	
		RowDescription.Parameters.ExtDimension1 = Selection.ExtDimension1;
		RowDescription.Parameters.ExtDimension2 = Selection.ExtDimension2;
		RowDescription.Parameters.ExtDimension3 = Selection.ExtDimension3;
		RowDescription.Parameters.Description = Selection.Description;
		If Account.Currency Then
			RowDescription.Parameters.Currency = Selection.Currency;
			RowDescription.Parameters.CurrencyAmount = Format(Selection.CurrencyAmount,"ND=15; NFD=2");
		EndIf;	
		
		RowAmount.Parameters.AmountDr = Format(Selection.AmountDr,"ND=15; NFD=2");
		RowAmount.Parameters.AmountCr = Format(Selection.AmountCr,"ND=15; NFD=2");
		
		
		TotalDr = TotalDr + Selection.AmountDr;
		TotalCr = TotalCr + Selection.AmountCr;
		
		CurBalance = CurBalance + Selection.AmountDr - Selection.AmountCr;
		
		TotalDrOnPage = TotalDrOnPage + Selection.AmountDr;
		TotalCrOnPage = TotalCrOnPage + Selection.AmountCr;
		
		
		If CurBalance > 0 Then
			RowTurnover.Parameters.Side = "Wn";
			RowTurnover.Parameters.Amount = Format(CurBalance,"ND=15; NFD=2");
		ElsIf CurBalance < 0 Then
			RowTurnover.Parameters.Side = "Ma";
			RowTurnover.Parameters.Amount = Format(-CurBalance,"ND=15; NFD=2");
		Else
			RowTurnover.Parameters.Side = "";
			RowTurnover.Parameters.Amount = Format(CurBalance,"ND=15; NFD=2");			
		EndIf;
		
		If OutputPageTotals Then
			
			SpreadSheetArray = New Array;
			SpreadSheetArray.Add(RowDescription);
			SpreadSheetArray.Add(TotalsDescription);
			
			If Not Result.CheckPut(SpreadSheetArray) Then
				
				TotalDrOnPage = TotalDrOnPage - Selection.AmountDr;
				TotalCrOnPage = TotalCrOnPage - Selection.AmountCr;
				
				TotalsAmount.Parameters.PageDrAmount = Format(TotalDrOnPage,"ND=15; NFD=2");
				TotalsAmount.Parameters.PageCrAmount = Format(TotalCrOnPage,"ND=15; NFD=2");
				
				TotalsAmount.Parameters.PrevDrAmount = Format(TotalDrOnPrevPage,"ND=15; NFD=2");
				TotalsAmount.Parameters.PrevCrAmount = Format(TotalCrOnPrevPage,"ND=15; NFD=2");
				
				TotalsAmount.Parameters.TotalDrAmount = Format(TotalDr,"ND=15; NFD=2");
				TotalsAmount.Parameters.TotalCrAmount = Format(TotalCr,"ND=15; NFD=2");
				
				TotalDrOnPrevPage = TotalDrOnPage;
				TotalCrOnPrevPage = TotalCrOnPage;
				
				TotalDrOnPage = 0 + Selection.AmountDr;
				TotalCrOnPage = 0 + Selection.AmountCr;
				
				Result.Put(TotalsDescription);
				Result.Join(TotalsAmount);
				Result.Join(TotalsTurnover);
				Result.PutHorizontalPageBreak();
				
			EndIf;
			
		EndIf;	
		
		Result.Put(RowDescription);
		Result.Join(RowAmount);
		Result.Join(RowTurnover);
		RowCount = RowCount + 1;
		
	EndDo;
	TotalsBriefAmount.Parameters.PageDrAmount = Format(TotalDrOnPage,"ND=15; NFD=2");
	TotalsBriefAmount.Parameters.PageCrAmount = Format(TotalCrOnPage,"ND=15; NFD=2");
	
	TotalsBriefAmount.Parameters.PrevDrAmount = Format(TotalDrOnPrevPage,"ND=15; NFD=2");
	TotalsBriefAmount.Parameters.PrevCrAmount = Format(TotalCrOnPrevPage,"ND=15; NFD=2");
	
	TotalsBriefAmount.Parameters.TotalDrAmount = Format(TotalDr,"ND=15; NFD=2");
	TotalsBriefAmount.Parameters.TotalCrAmount = Format(TotalCr,"ND=15; NFD=2");
	
	
	TotalsBriefAmount.Parameters.CloseBalanceDr = Format(ClosingBalanceDr,"ND=15; NFD=2");
	TotalsBriefAmount.Parameters.CloseBalanceCr = Format(ClosingBalanceCr,"ND=15; NFD=2");
	
	Result.Put(TotalsBriefDescription);      
	Result.Join(TotalsBriefAmount);
	Result.Join(TotalsBriefTurnover);
	
	// Header and footer values.
	Result.Header.Enabled   = True;
	Result.Footer.Enabled   = True;
	
	Result.Header.LeftText  = Nstr("pl='Firma';",LanguageCode)+": " + Common.GetLongDescription(Company) + " " + Nstr("en='VATNumber';pl='NIP';",LanguageCode)+": " + Taxes.GetVATNumberPresentationWithCash(Company.VATNumber, VATNumberTemplatesStructure, FormattedVATNumbersMap);
	Result.Header.RightText = Nstr("pl='Karta rachunków';",LanguageCode)+". " + Nstr("pl='Wygenerowany';",LanguageCode)+": " + GenerationDate;
	
	Result.Footer.LeftText  = CommonAtServer.GetGeneratedByText();
	Result.Footer.RightText = Nstr("pl = 'Strona [&PageNumber] z [&PagesTotal]'",LanguageCode);

	
EndFunction

// In procedure we can complete composer before output to report
// Changes will be not saved
Procedure CompleteComposerBeforeOutput() Export
	
	
			
EndProcedure

// Procedure fills report parameters by catalog item saved settings
Procedure ApplySetting() Export
	
	If SavedSetting.Isempty() Then
		Return;
	EndIf;
	
	SettingsStructure = SavedSetting.SettingsStorage.Get();
	TemplateReports.ApplyReportParametersStructure(ThisObject, SettingsStructure);
	
EndProcedure

Procedure FinalizeComposerAfterOutput() Export
EndProcedure

Procedure UpdateDataCompositionTemplateBeforeOutput(CompositionTemplate) Export
EndProcedure

Procedure ReportInitialization() Export
	
	TemplateReports.TemplateReportInitialization(ThisObject);
	BookkeepingReportInitializationData = BookkeepingAtServer.GetBookkeepingReportInitializationData();
	If Company.IsEmpty() Then
		TemplateReports.SetParameter(SettingsComposer,"Company",BookkeepingReportInitializationData.Company);
	EndIf;	
		
EndProcedure

Function UpdateSettingsComposerDependencesOnAccount(Account,SettingsComposer, ThisForm, DataCompositionSchemaAdress) Export
	
	Return BookkeepingAtServer.AccountsCard_UpdateDependencesOnAccount(Account,SettingsComposer, ThisForm.UniqueKey, DataCompositionSchemaAdress);
		
EndFunction	


#If Client Then
	
// For Settings report (details etc)
Procedure Setup(Filter, MainReportSettingsComposer = Undefined) Export
	
	TemplateReports.SetupTemplateReport(ThisObject, Filter, MainReportSettingsComposer);
	
EndProcedure

Procedure SaveSettings() Export
	
	SettingsStructure = TemplateReports.GetTemplateReportParametersStructure(ThisObject);
	SettingsSaving.SaveObjectSetting(SavedSetting, SettingsStructure);
	
EndProcedure

Procedure OpenReportFromDocument(NewSettingsOfComposer) Export 
	
	SettingsOfComposerOnOpenData = NewSettingsOfComposer;
	GenerateOnOpen = True;
	
EndProcedure

Details = New ValueList;

// Structure consists 
// ReportName - name of report in configuration
// Fields - Path to data, to fields, which should be drilldowned
//Item = New Structure;
//Item.Insert("ReportName", "TemplateOfTemplateReport");
//Item.Insert("Fields", "PurchaseGoodsExpected.Warehouse");
//Details.Add(Item, "Template of template report");

//Details.Add("ReportNameInConfiguration", "Report presentation for user");

PeriodSettings = New PeriodSettings;
GenerateOnOpen = False;
SettingsOfComposerOnOpenData = SettingsComposer.GetSettings();


#EndIf
