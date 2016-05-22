
////////////////////////////////////////////////////////////////////////////////
// GENERAL PURPOSE PROCEDURES AND FUNCTIONS

&AtServer
// Receives header template.
// 
Function GetHeaderTemplate(CompositionTemplate, Body = Undefined, TemplateType = "Title")
	
	If Body = Undefined Then
		Body = CompositionTemplate.Body;
	EndIf;
	
	If Body.Count() > 0 Then
		If TemplateType = "Title" Then
			StartingIndexOf = 0;
			FinalIndex  = Body.Count();
			StraightIterator  = True;
		ElsIf TemplateType = "Footer" Then 
			StartingIndexOf = Body.Count() - 1;
			FinalIndex  = 0;
			StraightIterator  = False;
		EndIf;
		
		IndexOf = StartingIndexOf;
		While IndexOf <> FinalIndex Do
			Item = Body[IndexOf];
			If TypeOf(Item) = Type("DataCompositionTemplateAreaTemplate") Then
				Return CompositionTemplate.Templates[Item.Template];
			EndIf;
			
			If StraightIterator Then
				IndexOf = IndexOf + 1;
			Else
				IndexOf = IndexOf - 1;
			EndIf;
		EndDo;	
	EndIf;
	
	Return Undefined;
	
EndFunction // GetHeaderTemplate()

&AtServer
// Receives footer template.
//
Function GetFooterTemplate(CompositionTemplate, Body = Undefined)
	
	If Body = Undefined Then
		Body = CompositionTemplate.Body;
	EndIf;
	
	For Each Item IN Body Do
		If TypeOf(Item) = Type("DataCompositionTemplateGroup") Then
			If Not IsBlankString(Item.FooterTemplate) Then
				Return CompositionTemplate.Templates[Item.FooterTemplate];
			EndIf;
		EndIf;
	EndDo;	
	
	Return Undefined;
	
EndFunction // GetFooterTemplate()

&AtServer
Function GetGroupingTemplateByGroupingField(CompositionTemplate, GroupingField, SearchInDetailedRecords = False, TemplateType = "Title")
	
	TemplatesArray = New Array;
	
	BypassCompositionTemplateBody(CompositionTemplate, CompositionTemplate.Body, TemplatesArray, GroupingField, SearchInDetailedRecords, TemplateType);	
	
	Return TemplatesArray;
	
EndFunction

&AtServer
// Bypass body of composition template.
//
Procedure BypassCompositionTemplateBody(CompositionTemplate, Body, TemplatesArray, GroupingField, SearchInDetailedRecords = False, TemplateType) 
	
	For Each Item IN Body Do
		If TypeOf(Item) = Type("DataCompositionTemplateGroup") Then
			For Each GroupItem IN Item.Group Do
				If Find(GroupItem.FieldName, GroupingField) = 1 Then 
					TemplateBodyOfThe = GetHeaderTemplate(CompositionTemplate, Item.Body, TemplateType);
					If TemplateBodyOfThe <> Undefined Then
						TemplatesArray.Add(TemplateBodyOfThe);  
					EndIf;
					TemplateHierarchicalBody = GetHeaderTemplate(CompositionTemplate, Item.HierarchicalBody, TemplateType);
					If TemplateHierarchicalBody <> Undefined Then
						TemplatesArray.Add(TemplateHierarchicalBody);
					EndIf;
				EndIf; 
				BypassCompositionTemplateBody(CompositionTemplate, Item.Body, TemplatesArray, GroupingField, SearchInDetailedRecords, TemplateType);
			EndDo;
		EndIf;
		If SearchInDetailedRecords Then
			If TypeOf(Item) = Type("DataCompositionTemplateRecords") Then
				If Item.Name = GroupingField Then
					TemplatesArray.Add(GetHeaderTemplate(CompositionTemplate, Item.Body));	
				EndIf;
			EndIf;			
		EndIf;
	EndDo;
	
EndProcedure // BypassCompositionTemplateBody()

&AtServer
// Function returns the filter item by the filter field.
//
Function GetFilterItem(DataCompositionSettings, FilterField, UseSign = Undefined)
	
	For Each FilterItem IN DataCompositionSettings.Filter.Items Do
		If FilterItem.LeftValue = FilterField Then
			If UseSign = Undefined Then
				Return FilterItem;
			Else
				If FilterItem.Use = UseSign Then
					Return FilterItem;
				EndIf;
			EndIf;
		EndIf;
	EndDo;
	
	Return Undefined;
	
EndFunction // GetFilterItem()

&AtServer
// Procedure corrects composition templates for cells displaying currency amounts information.
// 
Procedure BeforeReportOutput(CompositionTemplate) 
	
	HeaderTemplateReport = GetHeaderTemplate(CompositionTemplate,,"Footer");
	If HeaderTemplateReport = Undefined Then
		HeaderTemplateReport = GetHeaderTemplate(CompositionTemplate,,"Title");
	EndIf;
	HeaderTemplateIndex = CompositionTemplate.Templates.IndexOf(HeaderTemplateReport);
	
	TemplateAmount = HeaderTemplateReport.Template[2];
	
	If IsAccountingCurrency Then
		TemplateAmountCur = HeaderTemplateReport.Template[3];
	EndIf;
	
	HeaderTemplateReport.Template.Delete(TemplateAmount);
	
	If IsAccountingCurrency Then
		HeaderTemplateReport.Template.Delete(TemplateAmountCur);
		
	EndIf;
	
	TemplateGroupsCurrency = GetGroupingTemplateByGroupingField(CompositionTemplate, "Currency");
	If TemplateGroupsCurrency.Count() > 0 Then
		TemplateGroupsCurrency = TemplateGroupsCurrency[0];
	Else
		TemplateGroupsCurrency = Undefined;
	EndIf;
	
	For n = (HeaderTemplateIndex + 1) To CompositionTemplate.Templates.Count() - 1 Do 
		Template = CompositionTemplate.Templates[n];
		If Not Template = TemplateGroupsCurrency AND IsAccountingCurrency Then
			Template.Template.Delete(Template.Template[1]);
		EndIf;
	EndDo;
	
EndProcedure // BeforeReportDisplay()

&AtServer
// Procedure calculates totals by the upper level
// accounts and display totals in template.
//
Procedure BeforeResultItemOutput(ArrayTotals, CompositionTemplate, CompositionDetailsData, ResultItem, TemplateAccount, TemplateFooter, Cancel = False)
	
	// Accumulate amount by the root accounts
	If ValueIsFilled(ResultItem.Template) Then
		If TemplateAccount.Find(CompositionTemplate.Templates[ResultItem.Template]) <> Undefined Then
			ValueAccount = CompositionDetailsData.Items[ResultItem.ParameterValues.P2.Value].GetFields()[0].Value;
			If Not ValueIsFilled(ValueAccount.Parent) AND Not ValueAccount.OffBalance Then
				For UnderIndex = 1 To 6 Do
					Value = ResultItem.ParameterValues[String(CompositionTemplate.Templates[ResultItem.Template].Template[0].Cells[UnderIndex].Items[0].Value)].Value;
					ArrayTotals[UnderIndex-1] = ArrayTotals[UnderIndex-1] + Value;
				EndDo;
			EndIf;
		EndIf;
	EndIf; 

	// We put the accumulated amount in the report footer
	If ResultItem.Template = TemplateFooter.Name Then
		For UnderIndex = 1 To 6 Do
			ResultItem.ParameterValues[String(TemplateFooter.Template[0].Cells[UnderIndex].Items[0].Value)].Value = ArrayTotals[UnderIndex-1];
		EndDo;
	EndIf;
	
EndProcedure // BeforeResultItemDisplay()

&AtServer
// Function returns filter settings corresponding encryption.
//
Function GetDetailsSettings(Details, ActionsPerformedByParameter)
	
	AvailableSettingsSource = New DataCompositionAvailableSettingsSource(CompositionSchema);
	DetailProcessing = New DataCompositionDetailsProcess(DetailsData, AvailableSettingsSource);
	
	NewCompositionSettings = DetailProcessing.ApplySettings(Details, ActionsPerformedByParameter);
	
	Return NewCompositionSettings;
	
EndFunction // GetDetailsSettings()
	
&AtServer
// Procedure of report update.
//
Function RefreshReport() Export 
	
	Result.Clear();
	
	If EncryptingMode Then
		
		DataCompositionSettings = GetFromTempStorage(CompositionSettings);
		
		If TypeOf(DataCompositionSettings) = Type("DataCompositionSettings") Then // It is encryption.
			Report.SettingsComposer.LoadSettings(DataCompositionSettings);
		Else//If TypeOf(DataCompositionSettings) = Type("DataCompositionUserSettings") Then This is filter. //
			Report.SettingsComposer.LoadUserSettings(DataCompositionSettings);
			DataCompositionSettings = Report.SettingsComposer.GetSettings();
		EndIf;
		
		EncryptingMode = False;
		
	Else
		DataCompositionSettings = Report.SettingsComposer.GetSettings();
	EndIf;
	
	// Check the correctness of entered dates
    ParameterBeginOfPeriod = DataCompositionSettings.DataParameters.FindParameterValue(New DataCompositionParameter("BeginOfPeriod"));
	If ParameterBeginOfPeriod = Undefined Then
		BeginOfPeriod = Undefined; 
	Else
		If ParameterBeginOfPeriod.Use Then
			If TypeOf(ParameterBeginOfPeriod.Value) = Type("Date") Then
		    	BeginOfPeriod = ParameterBeginOfPeriod.Value;		
			Else
				BeginOfPeriod = ParameterBeginOfPeriod.Value.Date;		
			EndIf;		
		Else
			BeginOfPeriod = Undefined;		
		EndIf;		
	EndIf;
	ParameterEndOfPeriod = DataCompositionSettings.DataParameters.FindParameterValue(New DataCompositionParameter("EndOfPeriod"));
	If ParameterEndOfPeriod = Undefined Then
		EndOfPeriod = Undefined; 
	Else
		If ParameterEndOfPeriod.Use Then
			If TypeOf(ParameterEndOfPeriod.Value) = Type("Date") Then
		    	EndOfPeriod = ParameterEndOfPeriod.Value;		
			Else
				EndOfPeriod = ParameterEndOfPeriod.Value.Date;		
			EndIf;		
		Else
			EndOfPeriod = Undefined;		
		EndIf;		
	EndIf;	
	If BeginOfPeriod <> Undefined AND EndOfPeriod <> Undefined AND BeginOfPeriod > EndOfPeriod Then		
		Message = New UserMessage();
		Message.Text = NStr("en = 'Incorrect period specification: start period can not be les or equal the end period!'");
		Message.Message();		
		Return Undefined;	
	EndIf; 
	
	FilterAccount = GetFilterItem(DataCompositionSettings, New DataCompositionField("Account"), True);
	If FilterAccount = Undefined Then
		FilterAccount = GetFilterItem(DataCompositionSettings, New DataCompositionField("Account"));
	EndIf;
	
	If FilterAccount.Use Then
		IsFilterOnAccount = True;
	Else
		IsFilterOnAccount = False;
	EndIf;
	
	ParameterCurrencyAmount = DataCompositionSettings.DataParameters.FindParameterValue(New DataCompositionParameter("CurrencyAmount"));
	If ParameterCurrencyAmount = Undefined Then
		CurrencyAmount = False;
	Else
		CurrencyAmount = ParameterCurrencyAmount.Value AND ParameterCurrencyAmount.Use;
	EndIf;
	
	If CurrencyAmount Then
		
		Structure = DataCompositionSettings.Structure[0].Structure.Add(Type("DataCompositionGroup"));
		
		GroupingField = Structure.GroupFields.Items.Add(Type("DataCompositionGroupField"));
		GroupingField.Use  = True;
		GroupingField.Field           = New DataCompositionField("Currency");
		GroupingField.GroupType = DataCompositionGroupType.Items;
		
		Structure.Selection.Items.Add(Type("DataCompositionAutoSelectedField"));
		Structure.Order.Items.Add(Type("DataCompositionAutoOrderItem"));
		
	EndIf;
		
	Schema = Reports.TurnoverBalanceSheet.GetTemplate("MainDataCompositionSchema");
	
	CompositionDetailsData = New DataCompositionDetailsData;
	
	//Generate template of data composition at template composer assistant
	TemplateComposer = New DataCompositionTemplateComposer;
	
	//As composition scheme will perform the report
	//schema As report settings - current report
	//settings Encryption data will be placed in EncryptionData
	CompositionTemplate = TemplateComposer.Execute(Schema, DataCompositionSettings, CompositionDetailsData);
	
	ReportFooterTemplate     = GetFooterTemplate(CompositionTemplate);
	GroupTemplateAccount   = GetGroupingTemplateByGroupingField(CompositionTemplate, "Account");
	
	BeforeReportOutput(CompositionTemplate);
	
	//Create and initialize a composition processor
	CompositionProcessor = New DataCompositionProcessor;
	CompositionProcessor.Initialize(CompositionTemplate, , CompositionDetailsData, True);
	
	//Create and initialize the result output processor
	OutputProcessor = New DataCompositionResultSpreadsheetDocumentOutputProcessor;
	OutputProcessor.SetDocument(Result);
	
	ArrayHeaderResources = New Array; 
	
	//Indicate the output begin
	OutputProcessor.BeginOutput();
	TableFixed = False;  

	Result.FixedTop = 0;     
	
	ArrayTotals = New Array;
	For UnderIndex = 0 To 5 Do
		ArrayTotals.Add(0);
	EndDo;
	
	//Main cycle of the report output
	While True Do
		
		//Get the next item of a composition result
		ResultItem = CompositionProcessor.Next();
		If ResultItem = Undefined Then
			//The next item is not received - end the output cycle
			Break;
		Else
			Cancel = False;
			If Not IsFilterOnAccount Then
				BeforeResultItemOutput(ArrayTotals, CompositionTemplate, CompositionDetailsData, ResultItem, GroupTemplateAccount, ReportFooterTemplate, Cancel);
			EndIf;
			If Not Cancel Then
				// Fix header    
				If  Not TableFixed 
					  AND ResultItem.ParameterValues.Count() > 0 
					  AND TypeOf(Report.SettingsComposer.Settings.Structure[0]) <> Type("DataCompositionChart") Then

					TableFixed = True;
					Result.FixedTop = Result.TableHeight;

				EndIf;      
				
				//Item is received - output it using an output processor
				OutputProcessor.OutputItem(ResultItem);
			EndIf;
		EndIf;
		
	EndDo;
	
	//Specify display ehd
	OutputProcessor.EndOutput();
	DetailsData = PutToTempStorage(CompositionDetailsData, ThisForm.UUID);
	CompositionSchema = PutToTempStorage(Schema, ThisForm.UUID);
	
	Return Undefined;
	
EndFunction // UpdateReport()

&AtServer
// Function returns the document form name.
//
Function GetDocumentFormName(Document)
	
	NameOfFormDocument = "Document." + Document.Metadata().Name + ".ObjectForm";
	
	Return NameOfFormDocument;
	
EndFunction // GetDocumentFormName()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM EVENT HANDLERS

&AtServer
// Procedure - OnCreateAtServer event handler.
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	IsAccountingCurrency = Constants.FunctionalCurrencyTransactionsAccounting.Get();
	
	If Parameters.Property("EncryptingMode") Then
		EncryptingMode = Parameters.EncryptingMode;
		CompositionSettings = Parameters.CompositionSettings;
	Else
		EncryptingMode = False;
	EndIf;
	
EndProcedure // OnCreateAtServer()

&AtClient
// Procedure - event handler OnOpen.
//
Procedure OnOpen(Cancel)
	
	RefreshReport();

EndProcedure // OnOpen()

&AtServer
Procedure OnSaveUserSettingsAtServer(Settings)
	ReportsVariants.OnSaveUserSettingsAtServer(ThisObject, Settings);
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - ACTIONS OF THE FORM COMMAND PANELS

&AtClient
// Procedure - event handler GenerateReport.
//
Procedure GenerateReport(Command)
	RefreshReport();
EndProcedure // GenerateReport() 

&AtClient
// Procedure - event handler EncryptionDataProcessor fields Result.
//
Procedure ResultDetailProcessing(Item, Details, StandardProcessing)
	
	StandardProcessing = False;
	
	AvailableSettingsSource = New DataCompositionAvailableSettingsSource(CompositionSchema);
	
	DetailProcessing = New DataCompositionDetailsProcess(DetailsData, AvailableSettingsSource);
	
	AvailableActions = New Array();
	AvailableActions.Add(DataCompositionDetailsProcessingAction.DrillDown);
	AvailableActions.Add(DataCompositionDetailsProcessingAction.OpenValue);
	AvailableActions.Add(DataCompositionDetailsProcessingAction.Filter);
	
	AdditionalParameters = New Structure("Details", Details);
	NotifyDescription = New NotifyDescription("ResultDetailDataProcessorEnd", ThisObject, AdditionalParameters);
	
	DetailProcessing.ShowActionChoice(NOTifyDescription, Details);

EndProcedure

&AtClient
Procedure ResultDetailDataProcessorEnd(ExecutedAction, ActionsPerformedByParameter, AdditionalParameters) Export
    
    Details = AdditionalParameters.Details;
    
    If ActionsPerformedByParameter <> Undefined Then
        
        If ExecutedAction = DataCompositionDetailsProcessingAction.OpenValue Then
            
            If ValueIsFilled(ActionsPerformedByParameter) Then
                
                DetailsParameter = New Structure("Key", ActionsPerformedByParameter);
                
                If TypeOf(ActionsPerformedByParameter) = Type("ChartOfAccountsRef.Managerial") Then
                    
                    OpenForm("ChartOfAccounts.Managerial.Form.AccountForm", DetailsParameter);
                    
                Else
                    
                    OpenForm(GetDocumentFormName(ActionsPerformedByParameter), DetailsParameter);
                    
                EndIf;
                
            EndIf;
            
        ElsIf ExecutedAction = DataCompositionDetailsProcessingAction.DrillDown
            OR   ExecutedAction = DataCompositionDetailsProcessingAction.Filter Then
            
            NewCompositionSettings = GetDetailsSettings(Details, ActionsPerformedByParameter);
            
            CompositionSettings = PutToTempStorage(NewCompositionSettings, ThisForm.UUID);
            
            ParametersStructure = New Structure;
            ParametersStructure.Insert("EncryptingMode", True);
            ParametersStructure.Insert("CompositionSettings", CompositionSettings);
            
            OpenForm("Report.TurnoverBalanceSheet.Form.ReportForm", ParametersStructure, , New UUID);
            
        EndIf;			
        
    EndIf;
    
EndProcedure



