
&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	ActiveWindow = ActiveWindow();
	If ActiveWindow <> Undefined Then
		WindowProcessing(ActiveWindow);
		Return;
	EndIf;
	
	Windows = GetWindows();
	
	vlWindows = New ValueList;
	For each window Из Windows Do
		If window.IsMain Then
			Continue;
		EndIf;
		
		vlWindows.Add(window, window.Caption);
	EndDo;
	
	If vlWindows.Count() = 0 Then
		ShowMessageBox(, NStr("ru = 'Нет активных окон'; en = 'No active windows found'"));
		Return;
	ElsIf vlWindows.Count() = 1 Then
		WindowProcessing(vlWindows[0].Value);
	Else
		vlWindows.ShowChooseItem(New NotifyDescription("WindowChoiceProcessing", ThisObject));
	EndIf;
	
EndProcedure

&AtClient
Procedure WindowProcessing(currentWindow)
	vlForms = New ValueList;
	For each currentForm in currentWindow.Content Do
		vlForms.Add(currentForm, currentForm.FormName);
	EndDo;
	
	If vlForms.Count() = 1 Then
		FormProcessing(vlForms[0].Value);
	Else
		vlForms.ShowChooseItem(New NotifyDescription("FormChoiceProcessing", ThisObject));
	EndIf;
	
EndProcedure

&AtClient
Procedure FormProcessing(currentForm)
	Try
		strAddress = currentForm.RiseGetFormInterfaceClient();
	Except
		strErrorDescription = ErrorDescription();		
		ShowMessageBox(, NStr(StrTemplate("ru = 'Не удалось открыть окно проверки перевода формы ""%1"".'; en = 'Could not open translation checking window for ""%1"" form.'", currentForm.FormName)) + "
							|
							|" + strErrorDescription);
		Return;
	EndTry;
	
	If Not IsBlankString(strAddress) Then
		ActiveItem = currentForm.CurrentItem;
		If TypeOf(ActiveItem) = Тип("FormTable") Then
			ActiveItem = ActiveItem.CurrentItem;
		EndIf;
		If ActiveItem = Undefined Or TypeOf(ActiveItem) = Type("FormMainItem") Then
			ActiveItemName = "";
		Else
			ActiveItemName = ActiveItem.Name;
		EndIf;
		
		form = GetForm("CommonForm.RiseTranslationChecking", New Structure("TreeAddress, ActiveItem", strAddress, ActiveItemName), currentForm);
		form.Open();
	EndIf;
EndProcedure

&AtClient
Procedure WindowChoiceProcessing(SelectedElement, AdditionalParameters)
    If SelectedElement = Undefined Then
        Return
    Else
        WindowProcessing(SelectedElement.Value);
    EndIf;
EndProcedure

&AtClient
Procedure FormChoiceProcessing(SelectedElement, AdditionalParameters)
    If SelectedElement = Undefined Then
        Return;
    Else
        FormProcessing(SelectedElement.Value);
    EndIf;
EndProcedure