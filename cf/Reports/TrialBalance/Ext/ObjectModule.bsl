
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

Procedure CreateColumnsForTotalsRulesAndSplittedBalanceRules(TotalsRules, SplittedBalanceRules) Export
	
	TypeDescriptionString = Common.GetStringTypeDescription(200);
	
	BooleanArray        = New Array;
	TypeDescriptionBoolean = New TypeDescription("Boolean");
	
	ArrayValueTable       = New Array;
	TypeDescriptionValueTable = New TypeDescription("ValueTable");
	
	ArrayAccount = New Array;
	ArrayAccount.Add(TypeOf(ChartsOfAccounts[Metadata.AccountingRegisters.Bookkeeping.ChartOfAccounts.Name].EmptyRef()));
	TypeDescriptionAccount  = New TypeDescription(ArrayAccount);
	
	// Create attributes structure - tables
	If TotalsRules <> Undefined Then
		
		TotalsRules.Columns.Clear();
		TotalsRules.Columns.Add("Account",     TypeDescriptionAccount);
		TotalsRules.Columns.Add("ExtDimensionPresentation", TypeDescriptionString);
		TotalsRules.Columns.Add("ExtDimensionTurnover", TypeDescriptionValueTable);
		
	EndIf;
	
	If SplittedBalanceRules <> Undefined Then
		
		SplittedBalanceRules.Columns.Clear();
		SplittedBalanceRules.Columns.Add("Account",     TypeDescriptionAccount);
		SplittedBalanceRules.Columns.Add("ExtDimensionPresentation", TypeDescriptionString);
		SplittedBalanceRules.Columns.Add("ExtDimensionTurnover", TypeDescriptionValueTable);
		
	EndIf;
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
		
		If ValueIsNotFilled(FinancialYear) Then
			FinancialYearDescription = NStr("en = 'Financial year is not set!'; pl = 'Rok obrotowy nie jest ustawiony!'");
		Else
			FinancialYeardescription = NStr("en = 'Financial year from'; pl = 'Rok obrotowy od'") + " " + Format(FinancialYear.DateFrom, "DLF=D") + NStr("en = ' to '; pl = ' do '") + Format(EndOfDay(FinancialYear.DateTo), "DLF=D");
		EndIf;
		
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
		         		
		#If Not ThickClientOrdinaryApplication Then
		TableTotalsRules = ReportsModulesAtClientAtServer.GetSettingsParameter(SettingsComposer.Settings,"TotalsRulesExchange").Value.Get();
		TotalsRules      = TableTotalsRules;
		#EndIf  
			    		
		UsedAccountsValueList = New ValueList();
		UsedAccountsValueList.LoadValues(TotalsRules.UnloadColumn("Account"));
		
		TemplateReports.SetParameter(SettingsComposer,"ByOffBalance",ByOffBalance);
		
		StringToGroup = "";
		TransFormattedTotalsTable = New ValueTable;
		TransFormattedTotalsTable.Columns.Add("Account");
		For i=1 To Metadata.ChartsOfAccounts.Bookkeeping.MaxExtDimensionCount Do
			TransFormattedTotalsTable.Columns.Add("Field"+i);
			StringToGroup = StringToGroup + "Field"+i + ", ";
		EndDo;	
		TransFormattedTotalsTable.Columns.Add("Field"+(Metadata.ChartsOfAccounts.Bookkeeping.MaxExtDimensionCount+1));
		StringToGroup = StringToGroup + "Field"+(Metadata.ChartsOfAccounts.Bookkeeping.MaxExtDimensionCount+1);
		
		SplittedFieldsMap = New Map();
		
		For Each TotalsRulesRow In TotalsRules Do
			
			NewRow = TransFormattedTotalsTable.Add();
			NewRow.Account = TotalsRulesRow.Account;
			
			ArrayOfDetails = New ValueList();
			ArrayOfSplittedBalance = New ValueList();
			
			For i=0 To TotalsRulesRow.ExtDimensionTurnover.count()-1 Do
				
				TotalsRulesExtDimensionTurnoverRow = TotalsRulesRow.ExtDimensionTurnover[i];
				
				If TotalsRulesExtDimensionTurnoverRow.Balance = Enums.AccountDetailingTypes.SplittedAndDetailing Then
					ArrayOfDetails.Add(TotalsRulesExtDimensionTurnoverRow.Name);
				ElsIf TotalsRulesExtDimensionTurnoverRow.Balance = Enums.AccountDetailingTypes.Splitted Then	
					ArrayOfSplittedBalance.Add(TotalsRulesExtDimensionTurnoverRow.Name);
				EndIf;	
				
			EndDo;	
			
			i=0;
			For Each Item In ArrayOfDetails Do
				NewRow["Field"+(i+1)] = Item.Value;
				i=i+1;	
			EndDo;	
			
			For Each Item In ArrayOfSplittedBalance Do
				NewRow["Field"+(i+1)] = Item.Value;
				i=i+1;	
			EndDo;	
			
			SplittedFieldsMap.Insert(TotalsRulesRow.Account,ArrayOfSplittedBalance);
			
		EndDo;	
		
		TransFormattedTotalsTableModif2 = TransFormattedTotalsTable.Copy();
		TransFormattedTotalsTableModif2.GroupBy(StringToGroup);
		TransFormattedTotalsTableModif2.Columns.Add("AccountsToTotals");
		For Each TransFormattedTotalsTableModif2Row In TransFormattedTotalsTableModif2 Do
			
			TransFormattedTotalsTableModif2Row.AccountsToTotals = New Array();
			For Each TransFormattedTotalsTableRow In TransFormattedTotalsTable Do
				
				Equal = True;
				
				For i=1 To Metadata.ChartsOfAccounts.Bookkeeping.MaxExtDimensionCount + 1 Do
					
					If TransFormattedTotalsTableRow["Field"+i] <> TransFormattedTotalsTableModif2Row["Field"+i] Then
						
						Equal = False;
						
					EndIf;
					
				EndDo;	
				
				If Equal Then
					
					TransFormattedTotalsTableModif2Row.AccountsToTotals.Add(TransFormattedTotalsTableRow.Account);
					
				EndIf;	
				
			EndDo;	
			
		EndDo;	
		
		StructureForNestedSettings = SettingsComposer.Settings.Structure[0].Structure;
		StructureForNestedSettings.Clear();
		
		
		AccountsValueList = New ValueList();
		
		i = 0;
		
		For Each TransFormattedTotalsTableModif2Row In TransFormattedTotalsTableModif2 Do
			
			NewNestedGroupSetting = StructureForNestedSettings.Add(Type("DataCompositionNestedObjectSettings"));
			NewNestedGroupSetting.SetIdentifier("TotalsQuery");
			
			NewNestedGroupSetting.Settings.Filter.Items[0].Use = OnlyNonZeroBalance;
			
			ParameterValue = NewNestedGroupSetting.Settings.OutputParameters.FindParameterValue(New DataCompositionParameter("VerticalOverallPlacement"));
			ParameterValue.Value = DataCompositionTotalPlacement.None;
			ParameterValue.Use = True;
			
			TemplateReports.AddGroup(NewNestedGroupSetting,"NestedAccount");
			
			For j=1 To Metadata.ChartsOfAccounts.Bookkeeping.MaxExtDimensionCount + 1 Do
				
				If TransFormattedTotalsTableModif2Row["Field"+j]<>Undefined Then
					
					TemplateReports.AddGroup(NewNestedGroupSetting,TransFormattedTotalsTableModif2Row["Field"+j]);
					OrderItem = NewNestedGroupSetting.Settings.Order.Items.Add(Type("DataCompositionOrderItem"));
					OrderItem.Field = New DataCompositionField(TransFormattedTotalsTableModif2Row["Field"+j]+".Code");
					OrderItem.Use = True;
					OrderItem.OrderType = DataCompositionSortDirection.Asc;
					
				EndIf;	
				
			EndDo;	
			
			
			ValueList = New ValueList();
			ValueList.LoadValues(TransFormattedTotalsTableModif2Row.AccountsToTotals);
			
			For Each TmpAccount In TransFormattedTotalsTableModif2Row.AccountsToTotals Do
				AccountsValueList.Add(TmpAccount);
			EndDo;	
			
			AccountsToTotalsParameter = NewNestedGroupSetting.Settings.DataParameters.FindParameterValue(New DataCompositionParameter("AccountsToTotals"));
			AccountsToTotalsParameter.Use = True;
			AccountsToTotalsParameter.Value =TransFormattedTotalsTableModif2Row.AccountsToTotals;
			
			
			NewNestedGroupAvailableParameters =  NewNestedGroupSetting.Settings.DataParameters.AvailableParameters.Items;
			For Each Parameter In SettingsComposer.Settings.DataParameters.Items Do
				
				If NewNestedGroupAvailableParameters.Find(Parameter.Parameter) <> Undefined Then
					ReceiverFoundParameter = NewNestedGroupSetting.Settings.DataParameters.FindParameterValue(New DataCompositionParameter(Parameter.Parameter));
					SourceFoundParameter = SettingsComposer.Settings.DataParameters.FindParameterValue(New DataCompositionParameter(Parameter.Parameter));
					ReceiverFoundParameter.Use = SourceFoundParameter.Use;
					ReceiverFoundParameter.Value = SourceFoundParameter.Value;
				EndIf;	
				
			EndDo;
			
			NewNestedGroupAvailableFields =  NewNestedGroupSetting.Settings.Selection.SelectionAvailableFields.Items;
			For Each Selection In SettingsComposer.Settings.Selection.Items Do
				
				If NewNestedGroupAvailableFields.Find(Selection.Field) <> Undefined Then
					NewField = NewNestedGroupSetting.Settings.Selection.Items.Add(Type("DataCompositionSelectedField"));
					NewField.Field = Selection.Field;
				EndIf;	
				
			EndDo;
			
			
			NewFilter = NewNestedGroupSetting.Settings.Filter.Items.Add(Type("DataCompositionFilterItem"));
			NewFilter.LeftValue = New DataCompositionField("SettingsObjectOwner.Account");
			NewFilter.RightValue = New DataCompositionField("NestedAccount");
			NewFilter.ComparisonType = DataCompositionComparisonType.Equal;
			NewFilter.Use = True;
			
			i = i+1;
			
		EndDo;	
		
		Template = GetTemplate("Template");
		Template.TemplateLanguageCode = Common.GetDefaultLanguageCodeAndDescription().LanguageCode;
		
		Header = Template.GetArea("Header");
		RowTemplate = Template.GetArea("Row");
		RowCurrencyTemplate = Template.GetArea("RowCurrency");
		Totals = Template.GetArea("Totals");
		TotalsBrief = Template.GetArea("TotalsBrief");
		TotalsByBalance = Template.GetArea("TotalsByBalance");
		
		Result.FitToPage = True;
		Result.PageOrientation = PageOrientation.Landscape;
		Result.StartRowAutoGrouping();
		GenerationDate = CurrentDate(); // fixing generation time
		
		SettingsComposer.Settings.Filter.Items[0].Use = OnlyNonZeroBalance;
		SettingsComposer.Settings.Filter.Items[0].Items[0].RightValue = AccountsValueList;
		
		TemplateComposer = New DataCompositionTemplateComposer;
		CompositionTemplate = TemplateComposer.Execute(DataCompositionSchema, SettingsComposer.Settings, DetailsData, , Type("DataCompositionValueCollectionTemplateGenerator"));
				
		If OnlyIfHasTurnoversInPeriod Then
			
			CompositionTemplate.DataSets.MainQuery.Query = StrReplace(CompositionTemplate.DataSets.MainQuery.Query, "LEFT JOIN", "INNER JOIN");
			
			For i = 0 To TransFormattedTotalsTableModif2.Count()-1 Do	
				For Each Link In CompositionTemplate.Body[1].Body[i+1].DataComposition.DataSetLinks Do
					Link.LinkType = DataCompositionDataSetsLinkType.Inner;
				EndDo;	
			EndDo;
			
		EndIf;
		
		// Find header template 
		HeaderTemplate = Undefined;
		
		TemplatesStructure = New Structure();
		For Each CurrentTemplate In CompositionTemplate.Templates Do
			TemplatesStructure.Insert(CurrentTemplate.Name,CurrentTemplate.Template.Cells);
			If TypeOf(CurrentTemplate.Template) = Type("DataCompositionAreaTemplateValueCollectionHeader") Then	
				HeaderTemplate = CurrentTemplate.Template;
			EndIf;	
		EndDo;
		
		If HeaderTemplate = Undefined Then
			Return Undefined;
		EndIf;	
		
		RowStructure = New Structure;
		For Each Cell In HeaderTemplate.Cells Do
			RowStructure.Insert(Cell.Name);
		EndDo;
		
		
		GroupsValueList = TemplateReports.GetGroupsFields(SettingsComposer);
		NestedGroupsValueListArray = New Array();
		NestedHeaderTemplatesArray = New Array();
		For i = 0 To TransFormattedTotalsTableModif2.Count()-1 Do		
			
			NestedGroupsValueListArray.Add(TemplateReports.GetGroupsFields(SettingsComposer.Settings.Structure[0].Structure[i]));
			
			NestedHeaderTemplate = Undefined;
			For Each CurrentTemplate In CompositionTemplate.Body[1].Body[i+1].DataComposition.Templates Do
				If TypeOf(CurrentTemplate.Template) = Type("DataCompositionAreaTemplateValueCollectionHeader") Then	
					NestedHeaderTemplate = CurrentTemplate.Template;
				EndIf;	
			EndDo;
			
			NestedHeaderTemplatesArray.Add(NestedHeaderTemplate.Cells);
			
		EndDo;	
		
		CompositionProcessor = New DataCompositionProcessor;
		CompositionProcessor.Initialize(CompositionTemplate, , DetailsData, True);
		
		
		
		Header.Parameters.Company   = Common.GetLongDescription(Company);
		Header.Parameters.VATNumber = Taxes.GetVATNumberPresentation(Company.VATNumber);
		Header.Parameters.Address   = InformationRegisters.ContactInformation.Get(New Structure("Object, ContactInformationType, ContactInformationProfile", Company, Enums.ContactInformationTypes.Address, Catalogs.ContactInformationProfiles.CompanyLegalAddress)).Description;
		Header.Parameters.Period    = FinancialYearDescription + "; " + NStr("en = 'Period'; pl = 'Okres'") + " " + TemplateReports.GetReportPeriodDescription(SettingsComposer,LanguageCode);
		Header.Parameters.Filters   = String(SettingsComposer.Settings.Filter);
		
		Result.Put(Header);
		
		Result.RepeatOnRowPrint= Result.Area("RowsHeader");
		
		PageTotalsStructure = GetPageTotalsStructure();
		
		RowCount = 1;
		CurrentLevel = 0;
		PreviousLevel = 0;
		
		DetailsProcessingStructure = Undefined;
		FilledRowStructure = New Structure;
		
		AccountOffBalance = Undefined;
		SelectedAccount = Undefined;
		SelectedAccountDescription = Undefined;
		AccountLastLevel = Undefined;
		
		CurrentHeaderTemplate = Undefined;
		CurrentRowStructure = Undefined;
		CurrentTemplatesStructure = Undefined;	
		
		While True Do
			
			#If Client Then
				UserInterruptProcessing();
			#EndIf	
			
			ResultItem = CompositionProcessor.Next();
			
			If ResultItem = Undefined Then
				Break;
			EndIf;
			
			If ResultItem.Template = "" AND 
				ResultItem.Templates.Count()>0 Then
				
				
				CurrentTemplatesStructure = New Structure();
				
				For Each CurrentTemplate In ResultItem.Templates Do	
					CurrentTemplatesStructure.Insert(CurrentTemplate.Name,CurrentTemplate.Template.Cells);
					If TypeOf(CurrentTemplate.Template) = Type("DataCompositionAreaTemplateValueCollectionHeader") Then
						CurrentHeaderTemplate = CurrentTemplate.Template;
					EndIf;	
				EndDo;
				
				If CurrentHeaderTemplate <> Undefined Then
					
					CurrentRowStructure = New Structure;
					For Each Cell In CurrentHeaderTemplate.Cells Do
						CurrentRowStructure.Insert(Cell.Name);
					EndDo;
					
				EndIf;	
				
			EndIf;	
			
			
			If ResultItem.ItemType = DataCompositionResultItemType.Begin Then
				CurrentLevel = CurrentLevel + 1;
			ElsIf ResultItem.ItemType = DataCompositionResultItemType.End Then
				CurrentLevel = CurrentLevel - 1;
			EndIf;
			
			If ResultItem.ItemType <> DataCompositionResultItemType.BeginAndEnd Or ResultItem.ParameterValues.Count() = 0 Then
				Continue;	
			EndIf;
			
			If PreviousLevel >= CurrentLevel Then
				PageTotalsStructure.PageOpeningBalanceDr = PageTotalsStructure.PageOpeningBalanceDr + TransformateUndefinedToZero(FilledRowStructure.OpeningBalanceDr);
				PageTotalsStructure.PageOpeningBalanceCr = PageTotalsStructure.PageOpeningBalanceCr + TransformateUndefinedToZero(FilledRowStructure.OpeningBalanceCr);
				PageTotalsStructure.PagePeriodTurnoverDr = PageTotalsStructure.PagePeriodTurnoverDr + TransformateUndefinedToZero(FilledRowStructure.PeriodTurnoverDr);
				PageTotalsStructure.PagePeriodTurnoverCr = PageTotalsStructure.PagePeriodTurnoverCr + TransformateUndefinedToZero(FilledRowStructure.PeriodTurnoverCr);
				PageTotalsStructure.PageTurnoverDr       = PageTotalsStructure.PageTurnoverDr       + TransformateUndefinedToZero(FilledRowStructure.TurnoverDr);
				PageTotalsStructure.PageTurnoverCr       = PageTotalsStructure.PageTurnoverCr       + TransformateUndefinedToZero(FilledRowStructure.TurnoverCr);
				PageTotalsStructure.PageClosingBalanceDr = PageTotalsStructure.PageClosingBalanceDr + TransformateUndefinedToZero(FilledRowStructure.ClosingBalanceDr);
				PageTotalsStructure.PageClosingBalanceCr = PageTotalsStructure.PageClosingBalanceCr + TransformateUndefinedToZero(FilledRowStructure.ClosingBalanceCr);
				
				PageTotalsStructure.TotalOpeningBalanceDr = PageTotalsStructure.TotalOpeningBalanceDr + TransformateUndefinedToZero(FilledRowStructure.OpeningBalanceDr);
				PageTotalsStructure.TotalOpeningBalanceCr = PageTotalsStructure.TotalOpeningBalanceCr + TransformateUndefinedToZero(FilledRowStructure.OpeningBalanceCr);
				PageTotalsStructure.TotalPeriodTurnoverDr = PageTotalsStructure.TotalPeriodTurnoverDr + TransformateUndefinedToZero(FilledRowStructure.PeriodTurnoverDr);
				PageTotalsStructure.TotalPeriodTurnoverCr = PageTotalsStructure.TotalPeriodTurnoverCr + TransformateUndefinedToZero(FilledRowStructure.PeriodTurnoverCr);
				PageTotalsStructure.TotalTurnoverDr       = PageTotalsStructure.TotalTurnoverDr       + TransformateUndefinedToZero(FilledRowStructure.TurnoverDr);
				PageTotalsStructure.TotalTurnoverCr       = PageTotalsStructure.TotalTurnoverCr       + TransformateUndefinedToZero(FilledRowStructure.TurnoverCr);
				PageTotalsStructure.TotalClosingBalanceDr = PageTotalsStructure.TotalClosingBalanceDr + TransformateUndefinedToZero(FilledRowStructure.ClosingBalanceDr);
				PageTotalsStructure.TotalClosingBalanceCr = PageTotalsStructure.TotalClosingBalanceCr + TransformateUndefinedToZero(FilledRowStructure.ClosingBalanceCr);
				
				If AccountOffBalance = True Then
					PageTotalsStructure.TotalOpeningBalanceDrOffBalance = PageTotalsStructure.TotalOpeningBalanceDrOffBalance + TransformateUndefinedToZero(FilledRowStructure.OpeningBalanceDr);
					PageTotalsStructure.TotalOpeningBalanceCrOffBalance = PageTotalsStructure.TotalOpeningBalanceCrOffBalance + TransformateUndefinedToZero(FilledRowStructure.OpeningBalanceCr);
					PageTotalsStructure.TotalPeriodTurnoverDrOffBalance = PageTotalsStructure.TotalPeriodTurnoverDrOffBalance + TransformateUndefinedToZero(FilledRowStructure.PeriodTurnoverDr);
					PageTotalsStructure.TotalPeriodTurnoverCrOffBalance = PageTotalsStructure.TotalPeriodTurnoverCrOffBalance + TransformateUndefinedToZero(FilledRowStructure.PeriodTurnoverCr);
					PageTotalsStructure.TotalTurnoverDrOffBalance       = PageTotalsStructure.TotalTurnoverDrOffBalance       + TransformateUndefinedToZero(FilledRowStructure.TurnoverDr);
					PageTotalsStructure.TotalTurnoverCrOffBalance       = PageTotalsStructure.TotalTurnoverCrOffBalance       + TransformateUndefinedToZero(FilledRowStructure.TurnoverCr);
					PageTotalsStructure.TotalClosingBalanceDrOffBalance = PageTotalsStructure.TotalClosingBalanceDrOffBalance + TransformateUndefinedToZero(FilledRowStructure.ClosingBalanceDr);
					PageTotalsStructure.TotalClosingBalanceCrOffBalance = PageTotalsStructure.TotalClosingBalanceCrOffBalance + TransformateUndefinedToZero(FilledRowStructure.ClosingBalanceCr);
				ElsIf AccountOffBalance = False Then
					PageTotalsStructure.TotalOpeningBalanceDrBalance = PageTotalsStructure.TotalOpeningBalanceDrBalance + TransformateUndefinedToZero(FilledRowStructure.OpeningBalanceDr);
					PageTotalsStructure.TotalOpeningBalanceCrBalance = PageTotalsStructure.TotalOpeningBalanceCrBalance + TransformateUndefinedToZero(FilledRowStructure.OpeningBalanceCr);
					PageTotalsStructure.TotalPeriodTurnoverDrBalance = PageTotalsStructure.TotalPeriodTurnoverDrBalance + TransformateUndefinedToZero(FilledRowStructure.PeriodTurnoverDr);
					PageTotalsStructure.TotalPeriodTurnoverCrBalance = PageTotalsStructure.TotalPeriodTurnoverCrBalance + TransformateUndefinedToZero(FilledRowStructure.PeriodTurnoverCr);
					PageTotalsStructure.TotalTurnoverDrBalance       = PageTotalsStructure.TotalTurnoverDrBalance       + TransformateUndefinedToZero(FilledRowStructure.TurnoverDr);
					PageTotalsStructure.TotalTurnoverCrBalance       = PageTotalsStructure.TotalTurnoverCrBalance       + TransformateUndefinedToZero(FilledRowStructure.TurnoverCr);
					PageTotalsStructure.TotalClosingBalanceDrBalance = PageTotalsStructure.TotalClosingBalanceDrBalance + TransformateUndefinedToZero(FilledRowStructure.ClosingBalanceDr);
					PageTotalsStructure.TotalClosingBalanceCrBalance = PageTotalsStructure.TotalClosingBalanceCrBalance + TransformateUndefinedToZero(FilledRowStructure.ClosingBalanceCr);				
				EndIf;
				
			EndIf;
			
			PreviousLevel = CurrentLevel;
			
			If CurrentLevel%2 = 1 OR CurrentHeaderTemplate = Undefined Then
				GroupFieldNumber = (CurrentLevel - 1)/2 - 1;
				GroupFieldName = "Account";
				FilledRowStructure = GetRowStructure(ResultItem, TemplatesStructure, HeaderTemplate, RowStructure);
				CurrentHeaderTemplate = Undefined;
				AccountLastLevel = CurrentLevel;
				IsNested = False;
			Else
				// nested query
				GroupFieldNumber = (CurrentLevel - AccountLastLevel-1)/2-1;
				NestedGroupValueList = NestedGroupsValueListArray.Get(GetHeaderTemplateIndex(NestedHeaderTemplatesArray,CurrentHeaderTemplate));
				FilledRowStructure = GetRowStructure(ResultItem, CurrentTemplatesStructure, CurrentHeaderTemplate, CurrentRowStructure);
				GroupFieldName = StrReplace(NestedGroupValueList[GroupFieldNumber].Value, ".", "");
				If GroupFieldName <> "NestedAccount" Then
					SplittedFields = SplittedFieldsMap.Get(FilledRowStructure["NestedAccount"]);
					If SplittedFields<>Undefined AND SplittedFields.Count()>0 
						AND SplittedFields.FindByValue(GroupFieldName)<>Undefined Then
						Continue;
					EndIf;	
					IsNested = True;
				Else
					IsNested = False;
				EndIf;	
			EndIf;				
			
			GroupField = FilledRowStructure[GroupFieldName];
			
			If Upper(GroupFieldName) = Upper("Account") Then
				DetailsProcessingStructure = GetDetailsProcessingStructure();
				DetailsProcessingStructure.Account = FilledRowStructure["Account"];
				AccountOffBalance = FilledRowStructure["AccountOffBalance"];
				SelectedAccount = FilledRowStructure["Account"];
				SelectedAccountDescription = FilledRowStructure["AccountDescription"];
			ElsIf Upper(Left(GroupFieldName, StrLen(GroupFieldName) - 1)) = Upper("ExtDimension")
				OR Upper(GroupFieldName) = Upper("Currency") Then
				DetailsProcessingStructure[GroupFieldName] = GroupField;
			EndIf;	
			
			If Upper(GroupFieldName) = Upper("Currency") AND DetailsProcessingStructure<>Undefined Then
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
			
			Row.Parameters.DataDetails = DataDetails;
			Row.Parameters.RowNumber = RowCount;
			
			If Upper(GroupFieldName) = Upper("Account") 
				OR Upper(GroupFieldName) = Upper("NestedAccount") Then
				Row.Parameters.DataPresentation = "" + SelectedAccount + ", " + SelectedAccountDescription;
				Row.Area(1, 2, 1, 10).Font = New Font(Row.Area(1, 2).Font, , , True );
				If AccountOffBalance = True Then
					Row.Area(1, 2, 1, 10).BackColor = New Color(255,255,224);
				ElsIf AccountOffBalance = False Then
					Row.Area(1, 2, 1, 10).BackColor = New Color(255,255,255);
				EndIf;	
			Else
				If Upper(Left(GroupFieldName, StrLen(GroupFieldName) - 1)) = Upper("ExtDimension") Then
					If Catalogs.AllRefsType().ContainsType(TypeOf(GroupField)) Then
						Row.Parameters.DataPresentation = TrimAll(GroupField.Code) + ", " + GroupField;
					EndIf;	
				Else	
					Row.Parameters.DataPresentation =GroupField;
				EndIf;	
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
			
			If Upper(GroupFieldName) = Upper("Account") 
				AND UsedAccountsValueList.FindByValue(SelectedAccount) <> Undefined Then
				Continue;
			EndIf;	
			
			Result.Put(Row, GroupFieldNumber+?(IsNested,1,0));
			RowCount = RowCount + 1;		
			
		EndDo;	
		
		If ValueIsFilled(FilledRowStructure) Then
			
			PageTotalsStructure.PageOpeningBalanceDr = PageTotalsStructure.PageOpeningBalanceDr + TransformateUndefinedToZero(FilledRowStructure.OpeningBalanceDr);
			PageTotalsStructure.PageOpeningBalanceCr = PageTotalsStructure.PageOpeningBalanceCr + TransformateUndefinedToZero(FilledRowStructure.OpeningBalanceCr);
			PageTotalsStructure.PagePeriodTurnoverDr = PageTotalsStructure.PagePeriodTurnoverDr + TransformateUndefinedToZero(FilledRowStructure.PeriodTurnoverDr);
			PageTotalsStructure.PagePeriodTurnoverCr = PageTotalsStructure.PagePeriodTurnoverCr + TransformateUndefinedToZero(FilledRowStructure.PeriodTurnoverCr);
			PageTotalsStructure.PageTurnoverDr       = PageTotalsStructure.PageTurnoverDr       + TransformateUndefinedToZero(FilledRowStructure.TurnoverDr);
			PageTotalsStructure.PageTurnoverCr       = PageTotalsStructure.PageTurnoverCr       + TransformateUndefinedToZero(FilledRowStructure.TurnoverCr);
			PageTotalsStructure.PageClosingBalanceDr = PageTotalsStructure.PageClosingBalanceDr + TransformateUndefinedToZero(FilledRowStructure.ClosingBalanceDr);
			PageTotalsStructure.PageClosingBalanceCr = PageTotalsStructure.PageClosingBalanceCr + TransformateUndefinedToZero(FilledRowStructure.ClosingBalanceCr);
			
			PageTotalsStructure.TotalOpeningBalanceDr = PageTotalsStructure.TotalOpeningBalanceDr + TransformateUndefinedToZero(FilledRowStructure.OpeningBalanceDr);
			PageTotalsStructure.TotalOpeningBalanceCr = PageTotalsStructure.TotalOpeningBalanceCr + TransformateUndefinedToZero(FilledRowStructure.OpeningBalanceCr);
			PageTotalsStructure.TotalPeriodTurnoverDr = PageTotalsStructure.TotalPeriodTurnoverDr + TransformateUndefinedToZero(FilledRowStructure.PeriodTurnoverDr);
			PageTotalsStructure.TotalPeriodTurnoverCr = PageTotalsStructure.TotalPeriodTurnoverCr + TransformateUndefinedToZero(FilledRowStructure.PeriodTurnoverCr);
			PageTotalsStructure.TotalTurnoverDr       = PageTotalsStructure.TotalTurnoverDr       + TransformateUndefinedToZero(FilledRowStructure.TurnoverDr);
			PageTotalsStructure.TotalTurnoverCr       = PageTotalsStructure.TotalTurnoverCr       + TransformateUndefinedToZero(FilledRowStructure.TurnoverCr);
			PageTotalsStructure.TotalClosingBalanceDr = PageTotalsStructure.TotalClosingBalanceDr + TransformateUndefinedToZero(FilledRowStructure.ClosingBalanceDr);
			PageTotalsStructure.TotalClosingBalanceCr = PageTotalsStructure.TotalClosingBalanceCr + TransformateUndefinedToZero(FilledRowStructure.ClosingBalanceCr);
			
			If AccountOffBalance = True Then
				PageTotalsStructure.TotalOpeningBalanceDrOffBalance = PageTotalsStructure.TotalOpeningBalanceDrOffBalance + TransformateUndefinedToZero(FilledRowStructure.OpeningBalanceDr);
				PageTotalsStructure.TotalOpeningBalanceCrOffBalance = PageTotalsStructure.TotalOpeningBalanceCrOffBalance + TransformateUndefinedToZero(FilledRowStructure.OpeningBalanceCr);
				PageTotalsStructure.TotalPeriodTurnoverDrOffBalance = PageTotalsStructure.TotalPeriodTurnoverDrOffBalance + TransformateUndefinedToZero(FilledRowStructure.PeriodTurnoverDr);
				PageTotalsStructure.TotalPeriodTurnoverCrOffBalance = PageTotalsStructure.TotalPeriodTurnoverCrOffBalance + TransformateUndefinedToZero(FilledRowStructure.PeriodTurnoverCr);
				PageTotalsStructure.TotalTurnoverDrOffBalance       = PageTotalsStructure.TotalTurnoverDrOffBalance       + TransformateUndefinedToZero(FilledRowStructure.TurnoverDr);
				PageTotalsStructure.TotalTurnoverCrOffBalance       = PageTotalsStructure.TotalTurnoverCrOffBalance       + TransformateUndefinedToZero(FilledRowStructure.TurnoverCr);
				PageTotalsStructure.TotalClosingBalanceDrOffBalance = PageTotalsStructure.TotalClosingBalanceDrOffBalance + TransformateUndefinedToZero(FilledRowStructure.ClosingBalanceDr);
				PageTotalsStructure.TotalClosingBalanceCrOffBalance = PageTotalsStructure.TotalClosingBalanceCrOffBalance + TransformateUndefinedToZero(FilledRowStructure.ClosingBalanceCr);
			ElsIf AccountOffBalance = False Then
				PageTotalsStructure.TotalOpeningBalanceDrBalance = PageTotalsStructure.TotalOpeningBalanceDrBalance + TransformateUndefinedToZero(FilledRowStructure.OpeningBalanceDr);
				PageTotalsStructure.TotalOpeningBalanceCrBalance = PageTotalsStructure.TotalOpeningBalanceCrBalance + TransformateUndefinedToZero(FilledRowStructure.OpeningBalanceCr);
				PageTotalsStructure.TotalPeriodTurnoverDrBalance = PageTotalsStructure.TotalPeriodTurnoverDrBalance + TransformateUndefinedToZero(FilledRowStructure.PeriodTurnoverDr);
				PageTotalsStructure.TotalPeriodTurnoverCrBalance = PageTotalsStructure.TotalPeriodTurnoverCrBalance + TransformateUndefinedToZero(FilledRowStructure.PeriodTurnoverCr);
				PageTotalsStructure.TotalTurnoverDrBalance       = PageTotalsStructure.TotalTurnoverDrBalance       + TransformateUndefinedToZero(FilledRowStructure.TurnoverDr);
				PageTotalsStructure.TotalTurnoverCrBalance       = PageTotalsStructure.TotalTurnoverCrBalance       + TransformateUndefinedToZero(FilledRowStructure.TurnoverCr);
				PageTotalsStructure.TotalClosingBalanceDrBalance = PageTotalsStructure.TotalClosingBalanceDrBalance + TransformateUndefinedToZero(FilledRowStructure.ClosingBalanceDr);
				PageTotalsStructure.TotalClosingBalanceCrBalance = PageTotalsStructure.TotalClosingBalanceCrBalance + TransformateUndefinedToZero(FilledRowStructure.ClosingBalanceCr);				
			EndIf;
			
		EndIf;
		
		If OutputPageTotals Then
			FillPropertyValues(Totals.Parameters, PageTotalsStructure);
			Result.Put(Totals, 0);
		Else
			FillPropertyValues(TotalsBrief.Parameters, PageTotalsStructure);
			Result.Put(TotalsBrief, 0);
		EndIf;
		
		FillPropertyValues(TotalsByBalance.Parameters, PageTotalsStructure);	
		Result.Put(TotalsByBalance);
		
		Result.EndRowAutoGrouping();
		
		// Header and footer values.
		Result.Header.Enabled   = True;
		Result.Footer.Enabled   = True;
		
		Result.Header.LeftText  = Nstr("pl='Firma';",LanguageCode)+": " + Common.GetLongDescription(Company) + " " + Nstr("en='VAT Number';pl='NIP';",LanguageCode)+": " + Taxes.GetVATNumberPresentation(Company.VATNumber);
		Result.Header.RightText = Metadata().Synonym + ". " + TemplateReports.GetReportPeriodDescription(SettingsComposer) + " "+Nstr("pl='Wygenerowany';",LanguageCode)+": " + GenerationDate;
		
		Result.Footer.LeftText  = CommonAtServer.GetGeneratedByText();
		Result.Footer.RightText = Nstr("pl = 'Strona [&PageNumber] z [&PagesTotal]'",LanguageCode);
		
		For Each NestedGroupSetting In  StructureForNestedSettings Do
			
			AccountsToTotalsParameter = NestedGroupSetting.Settings.DataParameters.FindParameterValue(New DataCompositionParameter("AccountsToTotals"));
			AccountsToTotalsParameter.Use = True;
			AccountsToTotalsParameter.Value = ChartsOfAccounts.Bookkeeping.EmptyRef();
			
		EndDo;	
		
		If NeedToResetEndOfPeriod Then
			NeedToResetEndOfPeriod = False;
			TemplateReports.SetParameter(SettingsComposer,"EndOfPeriod",'00010101000000');
		EndIf;
		
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

Function GetPageTotalsStructure()
	
	PageTotalsStructure = New Structure();
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
	
	PageTotalsStructure.Insert("TotalOpeningBalanceDrBalance", 0);
	PageTotalsStructure.Insert("TotalOpeningBalanceCrBalance", 0);
	PageTotalsStructure.Insert("TotalPeriodTurnoverDrBalance", 0);
	PageTotalsStructure.Insert("TotalPeriodTurnoverCrBalance", 0);
	PageTotalsStructure.Insert("TotalTurnoverDrBalance", 0);
	PageTotalsStructure.Insert("TotalTurnoverCrBalance", 0);
	PageTotalsStructure.Insert("TotalClosingBalanceDrBalance", 0);
	PageTotalsStructure.Insert("TotalClosingBalanceCrBalance", 0);
	
	PageTotalsStructure.Insert("TotalOpeningBalanceDrOffBalance", 0);
	PageTotalsStructure.Insert("TotalOpeningBalanceCrOffBalance", 0);
	PageTotalsStructure.Insert("TotalPeriodTurnoverDrOffBalance", 0);
	PageTotalsStructure.Insert("TotalPeriodTurnoverCrOffBalance", 0);
	PageTotalsStructure.Insert("TotalTurnoverDrOffBalance", 0);
	PageTotalsStructure.Insert("TotalTurnoverCrOffBalance", 0);
	PageTotalsStructure.Insert("TotalClosingBalanceDrOffBalance", 0);
	PageTotalsStructure.Insert("TotalClosingBalanceCrOffBalance", 0);
	
	Return PageTotalsStructure;
	
EndFunction	

Function TransformateUndefinedToZero(Value)
	
	Return ?(Value = Undefined OR Value = Null,0,Value);
	
EndFunction	

Function GetRowStructure(ResultItem, CompositionTemplateStructure, HeaderTemplate, Val Structure)
	
	ChoosenTemplate = CompositionTemplateStructure[ResultItem.Template];
	For Each Cell In HeaderTemplate.Cells Do
		
		CellIndex = HeaderTemplate.Cells.IndexOf(Cell);
		CellName = Cell.Name;
		
		Parameter = ResultItem.ParameterValues.Find(ChoosenTemplate[CellIndex].Value);
		If Parameter = Undefined Then
			CellValue = Undefined;
		Else
			CellValue = Parameter.Value;
		EndIf;
		
		Structure[CellName] = CellValue;
		
	EndDo;
	
	CorrectedStructure = New Structure;
	AdditionalNumber = 0;
	AreExtDimensions = False;
	For Each KeyAndValue In Structure Do
		// ExtDimensions are skipped for now
		LastChar = Right(KeyAndValue.Key,1);
		If LastChar >="0" AND LastChar<="9" Then
			// there is digit in the end
			If StrLen(KeyAndValue.Key) = 13 AND Upper(Left(KeyAndValue.Key,12)) = Upper("ExtDimension") Then
				// skip ext dimensions
				AreExtDimensions = True;
			Else	
				CorrectedStructure.Insert(Mid(KeyAndValue.Key,1,StrLen(KeyAndValue.Key)-1),KeyAndValue.Value);
				AdditionalNumber = Number(LastChar);
			EndIf;	
		Else
			CorrectedStructure.Insert(KeyAndValue.Key,KeyAndValue.Value);
		EndIf;	
	EndDo;	
	
	If AreExtDimensions Then
		ExtDimensionsCorrespondence = New Map;
		For Each Cell In HeaderTemplate.Cells Do
			If StrLen(Cell.Name) = 13 AND Upper(Left(Cell.Name,12)) = Upper("ExtDimension") Then
				ExtDimensionsCorrespondence.Insert(Cell.Name,Left(Cell.Name,12)+Right(Cell.Title,1));
			EndIf;	
		EndDo;	
		// special loop for ext dimensions
		For Each KeyAndValue In Structure Do
			If StrLen(KeyAndValue.Key) = 13 AND Upper(Left(KeyAndValue.Key,12)) = Upper("ExtDimension") Then
				CorrectedStructure.Insert(ExtDimensionsCorrespondence.Get(KeyAndValue.Key),KeyAndValue.Value);
			EndIf;	
		EndDo;	
	EndIf;

	
	Return CorrectedStructure;
	
EndFunction

Function GetHeaderTemplateIndex(ArrayOfTemplates, TemplateToSearch)
	
	For i = 0 To ArrayOfTemplates.Count()-1 Do
		
		If ArrayOfTemplates[i].Count() <> TemplateToSearch.Cells.Count() Then
			Continue;
		EndIf;	
		
		Equal = True;
		
		For j=0 To ArrayOfTemplates[i].Count()-1 Do
			
			If ArrayOfTemplates[i][j].Name <> TemplateToSearch.Cells[j].Name Then
				Equal = False;
			EndIf;	
			
		EndDo;	
		
		If Equal Then
			Return i;
		EndIf;	
		
	EndDo;	
	
	Return -1;
	
EndFunction	

Function GetDetailsProcessingStructure()
	
	ReturnStructure = New Structure("Account, Currency",Undefined,Undefined);
	For i=1 To Metadata.ChartsOfAccounts.Bookkeeping.MaxExtDimensionCount Do
		ReturnStructure.Insert("ExtDimension"+i,Undefined);
	EndDo;	
	
	Return ReturnStructure;
	
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

CreateColumnsForTotalsRulesAndSplittedBalanceRules(TotalsRules, SplittedBalanceRules);
