////////////////////////////////////////////////////////////////////////////////
// Subsystem "Prohibition of object attributes editing"
// 
////////////////////////////////////////////////////////////////////////////////

#Region ServiceProceduresAndFunctions

Procedure AuthorizeObjectAttributesEditingAfterDoMessageBox(ContinuationProcessor) Export
	
	If ContinuationProcessor <> Undefined Then
		ExecuteNotifyProcessing(ContinuationProcessor, False);
	EndIf;
	
EndProcedure

Procedure AuthorizeObjectAttributesEditingAfterRefsCheck(Result, Parameters) Export
	
	If Result Then
		ObjectsAttributesEditProhibitionClient.SetAllowingAttributesEditing(
			Parameters.Form, Parameters.BlockedAttributes);
		
		ObjectsAttributesEditProhibitionClient.SetEnabledOfFormItems(Parameters.Form);
	EndIf;
	
	If Parameters.ContinuationProcessor <> Undefined Then
		ExecuteNotifyProcessing(Parameters.ContinuationProcessor, Result);
	EndIf;
	
EndProcedure

Procedure CheckReferencesToObjectAfterCheckConfirmation(Response, Parameters) Export
	
	If Response <> DialogReturnCode.Yes Then
		ExecuteNotifyProcessing(Parameters.ContinuationProcessor, False);
		Return;
	EndIf;
		
	If Parameters.RefArray.Count() = 0 Then
		ExecuteNotifyProcessing(Parameters.ContinuationProcessor, True);
		Return;
	EndIf;
	
	If CommonUseServerCall.ThereAreRefsToObject(Parameters.RefArray) Then
		
		If Parameters.RefArray.Count() = 1 Then
			MessageText = NStr("en='Item ""%1"" is already used in other places in the application.
		|It is not recommended to allow editing due to the risk of data misalignment.';ru='Элемент ""%1"" уже используется в других местах в программе.
		|Не рекомендуется разрешать редактирование из-за риска рассогласования данных.'");
			MessageText = StringFunctionsClientServer.PlaceParametersIntoString(MessageText, Parameters.RefArray[0]);
		Else
			MessageText = NStr("en='Selected items (%1) are already used in other places in the application.
		|It is not recommended to allow editing due to the risk of data misalignment.';ru='Выбранные элементы (%1) уже используются в других местах в программе.
		|Не рекомендуется разрешать редактирование из-за риска рассогласования данных.'");
			MessageText = StringFunctionsClientServer.PlaceParametersIntoString(MessageText, Parameters.RefArray.Count());
		EndIf;
		
		Buttons = New ValueList;
		Buttons.Add(DialogReturnCode.Yes, NStr("en='Allow edit';ru='Разрешить редактирование'"));
		Buttons.Add(DialogReturnCode.No, NStr("en='Cancel';ru='Отменить'"));
		ShowQueryBox(
			New NotifyDescription(
				"CheckReferencesToObjectAfterEditConfirmation", ThisObject, Parameters),
			MessageText, Buttons, , DialogReturnCode.No, Parameters.DialogTitle);
	Else
		If Parameters.RefArray.Count() = 1 Then
			ShowUserNotification(NStr("en='Attributes editing is allowed';ru='Редактирование реквизитов разрешено'"),
				GetURL(Parameters.RefArray[0]), Parameters.RefArray[0]);
		Else
			MessageText = StringFunctionsClientServer.PlaceParametersIntoString(
				NStr("en='Editing object attributes (%1) is allowed';ru='Разрешено редактирование реквизитов объектов (%1)'"), Parameters.RefArray.Count());
			ShowUserNotification(NStr("en='Attributes editing is allowed';ru='Редактирование реквизитов разрешено'"),, MessageText);
		EndIf;
		ExecuteNotifyProcessing(Parameters.ContinuationProcessor, True);
	EndIf;
	
EndProcedure

Procedure CheckReferencesToObjectAfterEditConfirmation(Response, Parameters) Export
	
	ExecuteNotifyProcessing(Parameters.ContinuationProcessor, Response = DialogReturnCode.Yes);
	
EndProcedure

#EndRegion
