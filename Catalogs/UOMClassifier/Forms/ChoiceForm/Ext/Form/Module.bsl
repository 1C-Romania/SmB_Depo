
////////////////////////////////////////////////////////////////////////////////
// SERVICE PROCEDURES AND FUNCTIONS

&AtClient
// Procedure opens units of measurement choice form according to classifier
//
//
Procedure AddMeasurementUnitFromClassifier()
	
	OpenForm("Catalog.UOMClassifier.Form.UOMClassifier", , ThisForm);
	
EndProcedure // AddMeasurementUnitFromClassifier()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM EVENT HANDLERS

&AtClient
// Procedure-handler of the NotificationProcessing event.
//
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "ChoiceMeasurementUnitFromClassifier" Then
		
		Items.List.Refresh();
		If ValueIsFilled(Parameter) Then
			
			Items.List.CurrentRow = Parameter;
			ThisForm.CurrentItem = Items.List;
			
		EndIf;
		
	EndIf;
	
EndProcedure // NotificationProcessing()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM COMMAND HANDLERS

&AtClient
// Command handler CommandPickFromClassifier.
//
Procedure PickFromClassifier(Command)
	
	AddMeasurementUnitFromClassifier();
	
EndProcedure // PickFromClassifier()

////////////////////////////////////////////////////////////////////////////////
// TABULAR SECTION EVENT HANDLERS

&AtClient
// Procedure - event handler BeforeAddStart tabular field List
//
Procedure ListBeforeAddRow(Item, Cancel, Copy, Parent, Group)
	
	QuestionText = NStr("en = 'There is an option to add the unit of measurement from the classifier. Add
		|from classifier? (Yes - add from classifier; No - add yourself; Cancel - cancel operation)'");
		
	ShowQueryBox(New NotifyDescription("ListBeforeAddingRowEnd", ThisObject),
		QuestionText,
		QuestionDialogMode.YesNoCancel
	);
	Cancel = True;
	Return;
	
EndProcedure // ListBeforeAddStart()

&AtClient
Procedure ListBeforeAddingRowEnd(Result, AdditionalParameters) Export
	
	Response = Result;
	
	If Response = DialogReturnCode.Yes Then
		
		AddMeasurementUnitFromClassifier();
		
	ElsIf Response = DialogReturnCode.No Then
		
		OpenForm("Catalog.UOMClassifier.Form.ItemForm");
		
	EndIf;
	
EndProcedure



