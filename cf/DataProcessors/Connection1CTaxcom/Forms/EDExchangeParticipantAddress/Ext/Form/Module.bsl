
// Storing context of interaction with the service
&AtClient
Var InteractionContext Export;

#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	ReadOnly = (Parameters.ReadOnly = True);
	
	IndexOf     = Parameters.IndexOf;
	Region     = Parameters.Region;
	District      = Parameters.District;
	City      = Parameters.City;
	Settlement   = Parameters.Settlement;
	Street      = Parameters.Street;
	Building        = Parameters.Building;
	Section     = Parameters.Section;
	Apartment   = Parameters.Apartment;
	StateCode = Parameters.StateCode;
	
	Items.ImportRef.Visible = Not ReadOnly;
	Items.FormCancel.Visible     = Items.ImportRef.Visible;
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, StandardProcessing)
	
	If Not SoftwareClosing AND Modified Then
		
		Cancel = True;
		
		NotifyDescription = New NotifyDescription("OnAnswerQuestionAboutSavingChangedData",
			ThisObject);
		
		QuestionText = NStr("en='Data changed. Save changes?';ru='Данные модифицированы. Сохранить изменения?'");
		ShowQueryBox(NOTifyDescription, QuestionText, QuestionDialogMode.YesNoCancel);
		
	EndIf;
	
EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

&AtClient
Procedure ImportRefClick(Item)
	
	// Pass command to server
	QueryParameters = New Array;
	QueryParameters.Add(New Structure("Name, Value", "getcodesregion", "true"));
	
	// Send parameters to server
	OnlineUserSupportClient.ServiceCommandsDataProcessor(InteractionContext,
		Undefined,
		QueryParameters);
	
EndProcedure

&AtClient
Procedure StateCodeStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
	StatesCodesList = OnlineUserSupportClientServer.SessionParameterValue(
		InteractionContext.COPContext,
		"codesRegionED");
	
	If StatesCodesList = Undefined Then
		
		WarningText = NStr("en='List of codes has not been imported yet. Click ""Import"" or enter the region code manually.';ru='Список кодов еще не загружен. Нажмите на ссылку ""Загрузить"" или введите код региона вручную.'");
		ShowMessageBox(, WarningText);
		Return;
		
	EndIf;
	
	CurrentListItem = StatesCodesList.FindByValue(StateCode);
	
	NotifyDescription = New NotifyDescription("OnSelectStateCode", ThisObject);
	
	StatesCodesList.ShowChooseItem(
		NotifyDescription,
		NStr("en='Region codes';ru='Коды регионов'"),
		CurrentListItem);
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure CommandOK(Command)
	
	Modified = False;
	
	If ThisObject.ReadOnly Then
		Close();
	Else
		// Return address data
		Close(PrepareReturnStructure());
	EndIf;
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

// Prepare a return structure with
// address data Return value: structure with margins - address attributes
//
&AtClient
Function PrepareReturnStructure()
	
	AnswerStructure = New Structure;
	AnswerStructure.Insert("IndexOf"          , IndexOf);
	AnswerStructure.Insert("Region"          , Region);
	AnswerStructure.Insert("StateCode"      , StateCode);
	AnswerStructure.Insert("District"           , District);
	AnswerStructure.Insert("City"           , City);
	AnswerStructure.Insert("Settlement" , Settlement);
	AnswerStructure.Insert("Street"           , Street);
	AnswerStructure.Insert("Building"             , Building);
	AnswerStructure.Insert("Section"          , Section);
	AnswerStructure.Insert("Apartment"        , Apartment);
	
	Return AnswerStructure;
	
EndFunction

&AtClient
Procedure OnAnswerQuestionAboutSavingChangedData(QuestionResult, AdditParameters) Export
	
	If QuestionResult = DialogReturnCode.Yes Then
		
		Modified = False;
		Close(PrepareReturnStructure());
		
	ElsIf QuestionResult = DialogReturnCode.No Then
		
		Modified = False;
		Close();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure OnSelectStateCode(SelectedItem, AdditParameters) Export
	
	If SelectedItem <> Undefined Then
		
		StateCode = SelectedItem.Value;
		If IsBlankString(Region) Then
			Region = Mid(SelectedItem.Presentation, 6);
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion
