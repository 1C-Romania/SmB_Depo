
// Specifies the text of the divided object state,
// sets the availability of the state control buttons and ReadOnly form flag 
//
Procedure ProcessManualEditFlag(Val Form) Export
	
	Items  = Form.Items;
	
	If Form.ManualChanging = Undefined Then
		Form.ManualEditText = NStr("en='The item is created manually. Automatic update is impossible.';ru='Элемент создан вручную. Автоматическое обновление не возможно.'");
		
		Items.UpdateFromClassifier.Enabled = False;
		Items.Change.Enabled = False;
		Form.ReadOnly          = False;
		Items.Parent.Enabled = True;
		Items.Code.Enabled      = True;
		If Not Form.Object.IsFolder Then
			Items.CorrAccount.Enabled = True;
		EndIf;
	ElsIf Form.ManualChanging = True Then
		Form.ManualEditText = NStr("en='Automatic item update is disabled.';ru='Автоматическое обновление элемента отключено.'");
		
		Items.UpdateFromClassifier.Enabled = True;
		Items.Change.Enabled = False;
		Form.ReadOnly          = False;
		Items.Parent.Enabled = False;
		Items.Code.Enabled      = False;
		If Not Form.Object.IsFolder Then
			Items.CorrAccount.Enabled = False;
		EndIf;
	Else
		Form.ManualEditText = NStr("en='Item is updated automatically.';ru='Элемент обновляется автоматически.'");
		
		Items.UpdateFromClassifier.Enabled = False;
		Items.Change.Enabled = True;
		Form.ReadOnly          = True;
	EndIf;
	
EndProcedure

// Prompts the user to update from the common data.
// IN case of an affirmative answer, it returns True.
//
Procedure RefreshItemFromClassifier(Val Form, ExecuteUpdate) Export
	
	QuestionText = NStr("en='The item data will be replaced with the data from the classifier."
"All manual changes will be lost. Continue?';ru='Данные элемента будут заменены данными из классификатора."
"Все ручные изменения будут потеряны. Продолжить?'");
							
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("Form", Form);
	AdditionalParameters.Insert("ExecuteUpdate", ExecuteUpdate);
	
	NotifyDescription = New NotifyDescription("DetermineNecessityForDataUpdateFromClassifier", Form, AdditionalParameters);
	ShowQueryBox(NOTifyDescription, QuestionText, QuestionDialogMode.YesNo, , DialogReturnCode.No);
	
EndProcedure
