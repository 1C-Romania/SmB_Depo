
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	Report.PeriodOfFormation = Items.PeriodOfFormation.ChoiceList[0];
	
EndProcedure

&AtClient
Procedure PeriodOfFormationOnChange(Item)
	
	SetConditionReportNotGenerated();
	
EndProcedure

&AtClient
Procedure SetConditionReportNotGenerated()
	
	Items.Result.StatePresentation.AdditionalShowMode = AdditionalShowMode.Irrelevance;
	Items.Result.StatePresentation.Text = NStr("en = 'Report is not generated. Click Create to generate the report.'");
	Items.Result.StatePresentation.Visible = True;
	
EndProcedure

&AtClient
Procedure ResultDetailProcessing(Item, Details, StandardProcessing)
	
	If TypeOf(Details) <> Type("DataCompositionDetailsID") Then
		Return;
	EndIf;
	
	StandardProcessing = False;
	
	FieldDetailsValue = GetDetailsFieldValue(Details);
	
	If ValueIsFilled(FieldDetailsValue) Then
		ParameterStructure = New Structure("Key", FieldDetailsValue.ValueDetails);
		OpenForm(FieldDetailsValue.NameOfFormDocument, ParameterStructure);
	EndIf;
	
EndProcedure

&AtServer
// Gets details field value.
//
Function GetDetailsFieldValue(Details)
	
	ReportObject = FormAttributeToValue("Report"); 
	
	SettingsSource = New DataCompositionAvailableSettingsSource(ReportObject.GetTemplate("MainDataCompositionSchema"));
	DetailProcessing = New DataCompositionDetailsProcess(DetailsData, SettingsSource);
		
	DetailsDataFromStorage = GetFromTempStorage(DetailsData);
	
	// Create and initialize detail handler.
	DetailsStructure = New Structure;
	
	ItemDetails = DetailsDataFromStorage.Items.Get(Details);
	
	If TypeOf(ItemDetails) = Type("DataCompositionFieldDetailsItem") Then
		For Each FieldDetailsValue IN ItemDetails.GetFields() Do
			If (FieldDetailsValue.Field = "Event"
				OR FieldDetailsValue.Field = "Counterparty"
				OR FieldDetailsValue.Field = "Responsible")
				AND ValueIsFilled(FieldDetailsValue.Value) Then
				
				ReturnStructure = New Structure;
				ReturnStructure.Insert("ValueDetails", FieldDetailsValue.Value);
				ReturnStructure.Insert("NameOfFormDocument", (?(FieldDetailsValue.Field = "Event", "Document.", "Catalog.")
					+ FieldDetailsValue.Value.Metadata().Name
					+ ".ObjectForm"
				));
				Return ReturnStructure;
			EndIf;
		EndDo;
	EndIf;
	
	Return Undefined;

EndFunction // GetDetailsFieldValue()

&AtServer
Procedure OnSaveUserSettingsAtServer(Settings)
	ReportsVariants.OnSaveUserSettingsAtServer(ThisObject, Settings);
EndProcedure






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
