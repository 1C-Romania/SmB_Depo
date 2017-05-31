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
	
	NationalCurrency = Constants.NationalCurrency.Get();
	
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
	
	MessageText = NStr("en = 'Please input Financial Year'; pl = 'Wypełnij pole Rok finansowy'");
	
	If FinancialYear.IsEmpty() Then
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
	
	GroupsValueList = TemplateReports.GetGroupsFields(SettingsComposer);	
	
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
			TemplateReports.SetParameter(SettingsComposer,"EndOfPeriod",EndOfDay(EndOfPeriod_Param.Value));
		EndIf;		
		
	EndIf;	

	
	Template = GetTemplate("Template");
	Template.TemplateLanguageCode = Common.GetDefaultLanguageCodeAndDescription().LanguageCode;
	
	Header = Template.GetArea("Header");
	RowTemplate = Template.GetArea("Row");
	RowCurrencyTemplate = Template.GetArea("RowCurrency");
	Totals = Template.GetArea("Totals");
	TotalsBrief = Template.GetArea("TotalsBrief");
		
	Result.PageOrientation = PageOrientation.Landscape;
	Result.StartRowAutoGrouping();
	GenerationDate = CurrentDate(); // fixing generation time
		

	CheckStructure(SettingsComposer.Settings.Structure);
	
	FilterUUID = Nstr("pl='Tylko niezerowe salda'");
	If OnlyNonZeroBalance Then
		BalanceFieldsArray = New Array;
		For Each CalculatedField In DataCompositionSchema.CalculatedFields Do
			
			CalculatedField.UseRestriction.Condition = False;
			
			If Find(Upper(CalculatedField.DataPath),Upper("ClosingBalance"))>0 Then
				BalanceFieldsArray.Add(CalculatedField.DataPath);
			EndIf;	
			
		EndDo;	
		NewGroupFilter = SettingsComposer.Settings.Filter.Items.Add(Type("DataCompositionFilterItemGroup"));
		NewGroupFilter.Use = True;
		NewGroupFilter.GroupType = DataCompositionFilterItemsGroupType.OrGroup;
		NewGroupFilter.Presentation = FilterUUID;
	
		For Each BalanceField In BalanceFieldsArray Do
			TemplateReports.AddFilter(NewGroupFilter,BalanceField,0,DataCompositionComparisonType.NotEqual);
		EndDo;	
	EndIf;	
	
	TemplateComposer = New DataCompositionTemplateComposer;
	CompositionTemplate = TemplateComposer.Execute(DataCompositionSchema, SettingsComposer.Settings, DetailsData, , Type("DataCompositionValueCollectionTemplateGenerator"));
	
	If OnlyIfHasTurnoversInPeriod Then
		CompositionTemplateLinks = CompositionTemplate.DataSetLinks;
		For Each Link In CompositionTemplateLinks Do
			Link.LinkType = DataCompositionDataSetsLinkType.Inner;
		EndDo;	
	EndIf;
		
	HeaderTemplate = Undefined;
	For Each CurrentTemplate In CompositionTemplate.Templates Do
		If TypeOf(CurrentTemplate.Template) = Type("DataCompositionAreaTemplateValueCollectionHeader") Then
			HeaderTemplate = CurrentTemplate.Template;
			Break;
		EndIf;
	EndDo;
	
	If HeaderTemplate = Undefined Then
		Return Undefined;
	EndIf;	
	
	RowStructure = New Structure;
	For Each Cell In HeaderTemplate.Cells Do
		RowStructure.Insert(Cell.Name);
	EndDo;
	
	CompositionProcessor = New DataCompositionProcessor;
	CompositionProcessor.Initialize(CompositionTemplate, , DetailsData, True);
	
	
	FinancialYearDescription = NStr("en = 'Financial year from'; pl = 'Rok obrotowy od'") + " " + Format(FinancialYear.DateFrom, "DLF=D") + NStr("en = ' to '; pl = ' do '") + Format(FinancialYear.DateTo, "DLF=D");

	Header.Parameters.Account   = Account;
	Header.Parameters.Company   = Common.GetLongDescription(Company);
	Header.Parameters.VATNumber = Taxes.GetVATNumberPresentation(Company.VATNumber);
	Header.Parameters.Address   = InformationRegisters.ContactInformation.Get(New Structure("Object, ContactInformationType, ContactInformationProfile", Company, Enums.ContactInformationTypes.Address, Catalogs.ContactInformationProfiles.CompanyLegalAddress)).Description;
	Header.Parameters.Period    = FinancialYearDescription + "; " + NStr("en = 'Period'; pl = 'Okres'") + " " + TemplateReports.GetReportPeriodDescription(SettingsComposer, LanguageCode);
	Header.Parameters.Filters   = String(SettingsComposer.Settings.Filter);
	
	ExtDimensionsDescription = NStr("en = 'Ext dimensions'; pl = 'Analityka'");
	If GroupsValueList.Count() > 0 Then
		ExtDimensionsDescription = ExtDimensionsDescription + ": ";
		For Each ListItem In GroupsValueList Do
			FoundExtDim = Find(ListItem.Value,"ExtDimension");
			If FoundExtDim = 0 Then
				Continue;
			EndIf;
			IndexAsString = Mid(ListItem.Value,FoundExtDim+StrLen("ExtDimension"),1);
			IndexAsNumber = 0;
			Try
				IndexAsNumber = Number(IndexAsString);
			Except
			 	IndexAsNumber = 0;
			EndTry;
			
			If IndexAsNumber <= 0 OR IndexAsNumber>Account.ExtDimensionTypes.Count() Then
				Continue;
			EndIf;	
			
			IndexAsNumber = IndexAsNumber - 1;
			
			FoundDot = Find(ListItem.Value,".");
			If FoundDot<>0 Then
				FoundDot = Find(ListItem.Presentation,".");
				DotText = Right(ListItem.Presentation,StrLen(ListItem.Presentation)-FoundDot+1);
			Else
				DotText = "";
			EndIf;	
			
			ExtDimensionsDescription = ExtDimensionsDescription + Account.ExtDimensionTypes[IndexAsNumber].ExtDimensionType.Description + DotText + ", ";
			
		EndDo;
		ExtDimensionsDescription = Left(ExtDimensionsDescription, StrLen(ExtDimensionsDescription) - 2);
	EndIf;
	
	Header.Parameters.ExtDimensions = ExtDimensionsDescription;
	
	Result.Put(Header);
	
	RowCount = 1;
	CurrentLevel = 0;
	PreviousLevel = 0;
	
	FilledRowStructure = New Structure;
	
	PageTotalsStructure = New Structure;
	PageTotalsStructure.Insert("PageOpeningBalanceDr", 0);
	PageTotalsStructure.Insert("PageOpeningBalanceCr", 0);
	PageTotalsStructure.Insert("PagePeriodTurnoverDr", 0);
	PageTotalsStructure.Insert("PagePeriodTurnoverCr", 0);
	PageTotalsStructure.Insert("PageTurnoverDr", 0);
	PageTotalsStructure.Insert("PageTurnoverCr", 0);
	PageTotalsStructure.Insert("PageClosingBalanceDr", 0);
	PageTotalsStructure.Insert("PageClosingBalanceCr", 0);
	
	PageTotalsStructure.Insert("PrevOpeningBalanceDr", 0);
	PageTotalsStructure.Insert("PrevOpeningBalanceCr", 0);
	PageTotalsStructure.Insert("PrevPeriodTurnoverDr", 0);
	PageTotalsStructure.Insert("PrevPeriodTurnoverCr", 0);
	PageTotalsStructure.Insert("PrevTurnoverDr", 0);
	PageTotalsStructure.Insert("PrevTurnoverCr", 0);
	PageTotalsStructure.Insert("PrevClosingBalanceDr", 0);
	PageTotalsStructure.Insert("PrevClosingBalanceCr", 0);
	
	PageTotalsStructure.Insert("TotalOpeningBalanceDr", 0);
	PageTotalsStructure.Insert("TotalOpeningBalanceCr", 0);
	PageTotalsStructure.Insert("TotalPeriodTurnoverDr", 0);
	PageTotalsStructure.Insert("TotalPeriodTurnoverCr", 0);
	PageTotalsStructure.Insert("TotalTurnoverDr", 0);
	PageTotalsStructure.Insert("TotalTurnoverCr", 0);
	PageTotalsStructure.Insert("TotalClosingBalanceDr", 0);
	PageTotalsStructure.Insert("TotalClosingBalanceCr", 0);
	
	While True Do
		
		#If Client Then
		UserInterruptProcessing();
		#EndIf
		
		ResultItem = CompositionProcessor.Next();
		
		If ResultItem = Undefined Then
			Break;
		EndIf;
		
		If ResultItem.ItemType = DataCompositionResultItemType.Begin Then
			CurrentLevel = CurrentLevel + 1;
		ElsIf ResultItem.ItemType = DataCompositionResultItemType.End Then
			CurrentLevel = CurrentLevel - 1;
		EndIf;
		
		If ResultItem.ItemType <> DataCompositionResultItemType.BeginAndEnd Or ResultItem.ParameterValues.Count() = 0 Then
			Continue;
		EndIf;
		
		If PreviousLevel >= CurrentLevel Then // sum totals
			
			PageTotalsStructure.PageOpeningBalanceDr = PageTotalsStructure.PageOpeningBalanceDr + FilledRowStructure.OpeningBalanceDr;
			PageTotalsStructure.PageOpeningBalanceCr = PageTotalsStructure.PageOpeningBalanceCr + FilledRowStructure.OpeningBalanceCr;
			PageTotalsStructure.PagePeriodTurnoverDr = PageTotalsStructure.PagePeriodTurnoverDr + FilledRowStructure.PeriodTurnoverDr;
			PageTotalsStructure.PagePeriodTurnoverCr = PageTotalsStructure.PagePeriodTurnoverCr + FilledRowStructure.PeriodTurnoverCr;
			PageTotalsStructure.PageTurnoverDr       = PageTotalsStructure.PageTurnoverDr       + FilledRowStructure.TurnoverDr;
			PageTotalsStructure.PageTurnoverCr       = PageTotalsStructure.PageTurnoverCr       + FilledRowStructure.TurnoverCr;
			PageTotalsStructure.PageClosingBalanceDr = PageTotalsStructure.PageClosingBalanceDr + FilledRowStructure.ClosingBalanceDr;
			PageTotalsStructure.PageClosingBalanceCr = PageTotalsStructure.PageClosingBalanceCr + FilledRowStructure.ClosingBalanceCr;
			
			PageTotalsStructure.TotalOpeningBalanceDr = PageTotalsStructure.TotalOpeningBalanceDr + FilledRowStructure.OpeningBalanceDr;
			PageTotalsStructure.TotalOpeningBalanceCr = PageTotalsStructure.TotalOpeningBalanceCr + FilledRowStructure.OpeningBalanceCr;
			PageTotalsStructure.TotalPeriodTurnoverDr = PageTotalsStructure.TotalPeriodTurnoverDr + FilledRowStructure.PeriodTurnoverDr;
			PageTotalsStructure.TotalPeriodTurnoverCr = PageTotalsStructure.TotalPeriodTurnoverCr + FilledRowStructure.PeriodTurnoverCr;
			PageTotalsStructure.TotalTurnoverDr       = PageTotalsStructure.TotalTurnoverDr       + FilledRowStructure.TurnoverDr;
			PageTotalsStructure.TotalTurnoverCr       = PageTotalsStructure.TotalTurnoverCr       + FilledRowStructure.TurnoverCr;
			PageTotalsStructure.TotalClosingBalanceDr = PageTotalsStructure.TotalClosingBalanceDr + FilledRowStructure.ClosingBalanceDr;
			PageTotalsStructure.TotalClosingBalanceCr = PageTotalsStructure.TotalClosingBalanceCr + FilledRowStructure.ClosingBalanceCr;
			
		EndIf;
		PreviousLevel = CurrentLevel;
		
		FilledRowStructure = GetRowStructure(ResultItem, CompositionTemplate, HeaderTemplate, RowStructure);
		
		GroupFieldNumber = (CurrentLevel - 1)/2 - 1;
		GroupFieldName = StrReplace(GroupsValueList[GroupFieldNumber].Value, ".", "");
		GroupField = FilledRowStructure[GroupFieldName];
		
		If GroupFieldNumber = 0 Then
			DetailsProcessingStructure = GetDetailsProcessingStructure();
		EndIf;	
		
		If Upper(Left(GroupFieldName, StrLen(GroupFieldName) - 1)) = Upper("ExtDimension") 
			OR Upper(GroupFieldName) = Upper("Currency")
			OR Upper(GroupFieldName) = Upper("Account") Then
			DetailsProcessingStructure[GroupFieldName] = GroupField;
		EndIf;	
		
		If Account.Currency AND Upper(GroupFieldName) = Upper("Currency") Then
			CurrencyValue = Undefined;
			If DetailsProcessingStructure.Property("Currency",CurrencyValue) Then
				If CurrencyValue = NationalCurrency Then
					Row = RowTemplate;
				Else	
					Row = RowCurrencyTemplate;
				EndIf;	
			Else
				Row = RowTemplate;
			EndIf;	
		Else
			Row = RowTemplate;
		EndIf;	
		
		DataDetails = GetDetailsProcessingStructure();
		FillPropertyValues(DataDetails,DetailsProcessingStructure);

		If GroupField = Undefined Then
			Row.Parameters.ExtDimensionPresentation = GroupField;
		ElsIf Catalogs.AllRefsType().ContainsType(TypeOf(GroupField)) Then
			Row.Parameters.ExtDimensionPresentation = TrimAll(GroupField.Code) + ", " + GroupField;
		ElsIf ChartsOfAccounts.AllRefsType().ContainsType(TypeOf(GroupField)) Then
			Row.Parameters.ExtDimensionPresentation = "" + GroupField + ", " + GroupField.Description;
		Else	
			Row.Parameters.ExtDimensionPresentation = GroupField;
		EndIf;	
		Row.Parameters.DataDetails = DataDetails;
		Row.Parameters.RowNumber = RowCount;
		
		If GroupFieldNumber < (GroupsValueList.Count()-1) Then
			Row.Area(1, 2, 1, 10).Font = New Font(Row.Area(1, 2).Font, , , True);
		Else
			Row.Area(1, 2, 1, 10).Font = New Font(Row.Area(1, 2).Font, , , False);
		EndIf;
		
		FillPropertyValues(Row.Parameters, FilledRowStructure);
		
		If OutputPageTotals Then
			
			SpreadSheetArray = New Array;
			SpreadSheetArray.Add(Row);
			SpreadSheetArray.Add(Totals);
			
			If Not Result.CheckPut(SpreadSheetArray) Then
				
				FillPropertyValues(Totals.Parameters, PageTotalsStructure);
				
				PageTotalsStructure.PageOpeningBalanceDr = 0;
				PageTotalsStructure.PageOpeningBalanceCr = 0;
				PageTotalsStructure.PagePeriodTurnoverDr = 0;
				PageTotalsStructure.PagePeriodTurnoverCr = 0;
				PageTotalsStructure.PageTurnoverDr       = 0;
				PageTotalsStructure.PageTurnoverCr       = 0;
				PageTotalsStructure.PageClosingBalanceDr = 0;
				PageTotalsStructure.PageClosingBalanceCr = 0;
				
				PageTotalsStructure.PrevOpeningBalanceDr = PageTotalsStructure.TotalOpeningBalanceDr;
				PageTotalsStructure.PrevOpeningBalanceCr = PageTotalsStructure.TotalOpeningBalanceCr;
				PageTotalsStructure.PrevPeriodTurnoverDr = PageTotalsStructure.TotalPeriodTurnoverDr;
				PageTotalsStructure.PrevPeriodTurnoverCr = PageTotalsStructure.TotalPeriodTurnoverCr;
				PageTotalsStructure.PrevTurnoverDr       = PageTotalsStructure.TotalTurnoverDr;
				PageTotalsStructure.PrevTurnoverCr       = PageTotalsStructure.TotalTurnoverCr;
				PageTotalsStructure.PrevClosingBalanceDr = PageTotalsStructure.TotalClosingBalanceDr;
				PageTotalsStructure.PrevClosingBalanceCr = PageTotalsStructure.TotalClosingBalanceCr;
				
				Result.Put(Totals);
				Result.PutHorizontalPageBreak();
				
			EndIf;
			
		EndIf;
		
		Result.Put(Row, GroupFieldNumber);
		RowCount = RowCount + 1;
		
	EndDo;
	
	If ValueIsFilled(FilledRowStructure) Then
		
		PageTotalsStructure.PageOpeningBalanceDr = PageTotalsStructure.PageOpeningBalanceDr + FilledRowStructure.OpeningBalanceDr;
		PageTotalsStructure.PageOpeningBalanceCr = PageTotalsStructure.PageOpeningBalanceCr + FilledRowStructure.OpeningBalanceCr;
		PageTotalsStructure.PagePeriodTurnoverDr = PageTotalsStructure.PagePeriodTurnoverDr + FilledRowStructure.PeriodTurnoverDr;
		PageTotalsStructure.PagePeriodTurnoverCr = PageTotalsStructure.PagePeriodTurnoverCr + FilledRowStructure.PeriodTurnoverCr;
		PageTotalsStructure.PageTurnoverDr       = PageTotalsStructure.PageTurnoverDr       + FilledRowStructure.TurnoverDr;
		PageTotalsStructure.PageTurnoverCr       = PageTotalsStructure.PageTurnoverCr       + FilledRowStructure.TurnoverCr;
		PageTotalsStructure.PageClosingBalanceDr = PageTotalsStructure.PageClosingBalanceDr + FilledRowStructure.ClosingBalanceDr;
		PageTotalsStructure.PageClosingBalanceCr = PageTotalsStructure.PageClosingBalanceCr + FilledRowStructure.ClosingBalanceCr;
		
		PageTotalsStructure.TotalOpeningBalanceDr = PageTotalsStructure.TotalOpeningBalanceDr + FilledRowStructure.OpeningBalanceDr;
		PageTotalsStructure.TotalOpeningBalanceCr = PageTotalsStructure.TotalOpeningBalanceCr + FilledRowStructure.OpeningBalanceCr;
		PageTotalsStructure.TotalPeriodTurnoverDr = PageTotalsStructure.TotalPeriodTurnoverDr + FilledRowStructure.PeriodTurnoverDr;
		PageTotalsStructure.TotalPeriodTurnoverCr = PageTotalsStructure.TotalPeriodTurnoverCr + FilledRowStructure.PeriodTurnoverCr;
		PageTotalsStructure.TotalTurnoverDr       = PageTotalsStructure.TotalTurnoverDr       + FilledRowStructure.TurnoverDr;
		PageTotalsStructure.TotalTurnoverCr       = PageTotalsStructure.TotalTurnoverCr       + FilledRowStructure.TurnoverCr;
		PageTotalsStructure.TotalClosingBalanceDr = PageTotalsStructure.TotalClosingBalanceDr + FilledRowStructure.ClosingBalanceDr;
		PageTotalsStructure.TotalClosingBalanceCr = PageTotalsStructure.TotalClosingBalanceCr + FilledRowStructure.ClosingBalanceCr;
		
	EndIf;
	
	If OutputPageTotals Then
		FillPropertyValues(Totals.Parameters, PageTotalsStructure);
		Result.Put(Totals, 0);
	Else
		FillPropertyValues(TotalsBrief.Parameters, PageTotalsStructure);
		Result.Put(TotalsBrief, 0);
	EndIf;
	
	Result.EndRowAutoGrouping();
	
	If NeedToResetEndOfPeriod Then
		NeedToResetEndOfPeriod = False;
		TemplateReports.SetParameter(SettingsComposer,"EndOfPeriod",'00010101000000');
	EndIf;
	
	If OnlyNonZeroBalance Then
		For Each CalculatedField In DataCompositionSchema.CalculatedFields Do
			
			CalculatedField.UseRestriction.Condition = True;
			
		EndDo;	
		For Each FilterItem In SettingsComposer.Settings.Filter.Items Do
			
			If FilterItem.Presentation = FilterUUID Then
				SettingsComposer.Settings.Filter.Items.Delete(FilterItem);
				Break;
			EndIf;	
			
		EndDo;	
	EndIf;	

	
	// Header and footer values.
	Result.Header.Enabled   = True;
	Result.Footer.Enabled   = True;
	
	Result.Header.LeftText  = Nstr("pl='Firma';",LanguageCode)+": " + Common.GetLongDescription(Company) + " " + Nstr("en='VAT Number';pl='NIP';",LanguageCode)+": " + Taxes.GetVATNumberPresentation(Company.VATNumber);
	Result.Header.RightText = Metadata().Synonym + ": " + Account + ". " + TemplateReports.GetReportPeriodDescription(SettingsComposer) + " " + Nstr("pl='Wygenerowany';",LanguageCode)+": " + GenerationDate;
	
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
	If Company.IsEmpty() Then
		Company = CommonAtServer.GetUserSettingsValue("Company",SessionParameters.CurrentUser);
		TemplateReports.SetParameter(SettingsComposer,"Company",Company);
	EndIf;	
	
	If FinancialYear.IsEmpty() Then
		FinancialYear = CommonAtServer.GetUserSettingsValue("DefaultFinancialYear",SessionParameters.CurrentUser);
		If FinancialYear.IsEmpty() Then
			FinancialYearDateFrom = '00010101000000';
			FinancialYearDateTo = '00010101000000';
		Else	
			FinancialYearDateFrom = BegOfDay(FinancialYear.DateFrom);
			FinancialYearDateTo = EndOfDay(FinancialYear.DateTo);
		EndIf;	
		
		TemplateReports.SetParameter(SettingsComposer,"BeginOfYear",FinancialYearDateFrom);
	EndIf;	
	
EndProcedure

Function GetRowStructure(ResultItem, CompositionTemplate, HeaderTemplate, Val Structure)
	
	For Each Cell In HeaderTemplate.Cells Do
		
		CellIndex = HeaderTemplate.Cells.IndexOf(Cell);
		CellName = Cell.Name;
		
		Parameter = ResultItem.ParameterValues.Find(CompositionTemplate.Templates[ResultItem.Template].Template.Cells[CellIndex].Value);
		If Parameter = Undefined Then
			CellValue = Undefined;
		Else
			CellValue = Parameter.Value;
		EndIf;
		
		Structure[CellName] = CellValue;
		
	EndDo;
	
	Return Structure;
	
EndFunction

Function GetDetailsProcessingStructure()
	
	Return New Structure("Account, ExtDimension1, ExtDimension2, ExtDimension3,Currency",Undefined,Undefined,Undefined,Undefined,Undefined);
	
EndFunction	

Function UpdateSettingsComposerDependencesOnAccount(Account,SettingsComposer,ThisForm, DataCompositionSchemaAdress) Export
	
	Return BookkeepingAtServer.TrialBalanceByAccount_UpdateDependencesOnAccount(Account,SettingsComposer, ThisForm.UniqueKey, DataCompositionSchemaAdress);;
	
EndFunction	

Procedure CheckStructure(CurrentStructure)
	
	For Each GroupItem In CurrentStructure Do
		
		WasUsed = False;
		
		For Each GroupField In GroupItem.GroupFields.Items Do
			
			If GroupItem.GroupFields.GroupFieldsAvailableFields.FindField(GroupField.Field)<> Undefined Then
				
				GroupField.Use = True;
				WasUsed = True;
				
			Else	
				
				GroupField.Use = False;
				
			EndIf;
		
		EndDo;
		
		GroupItem.Use = WasUsed;
		
		CheckStructure(GroupItem.Structure);
		
	EndDo	
	
EndProcedure	


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
