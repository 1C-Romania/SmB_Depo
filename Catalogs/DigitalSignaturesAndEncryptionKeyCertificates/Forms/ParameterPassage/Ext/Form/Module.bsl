&AtClient
Var CommonInternalData;

&AtClient
Var OperationsContextsTemporaryStorage;

#Region FormEventsHandlers

&AtClient
Procedure OnOpen(Cancel)
	
	CommonInternalData = New Map;
	Cancel = True;
	
	OperationsContextsTemporaryStorage = New Map;
	AttachIdleHandler("DeleteOutdatedOperationsContexts", 300);
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtClient
Procedure OpenNewForm(FormKind, ServerParameters, ClientParameters = Undefined,
			CompletionProcessing = Undefined, Val NewFormOwner = Undefined) Export
	
	FormsKinds = ",SigningData,DataEncryption,DataDetail, ,CertificateChoiceForSigningOrDecoding,CertificateCheck,";
	
	If Find(FormsKinds, "," + FormKind + ",") = 0 Then
		Raise StringFunctionsClientServer.PlaceParametersIntoString(
			NStr("en = 'Error in the procedure OpenNewForm. FormKind ""% 1"" is not supported.'"), FormKind);
	EndIf;
	
	If NewFormOwner = Undefined Then
		NewFormOwner = New UUID;
	EndIf;
	
	ContinuationProcessor = New NotifyDescription("OpenNewForm", ThisObject);
	
	NewFormName = "Catalog.DigitalSignaturesAndEncryptionKeyCertificates.Form." + FormKind;
	
	Form = GetForm(NewFormName, ServerParameters, NewFormOwner);
	
	If Form = Undefined Then
		If TypeOf(CompletionProcessing) = Type("NotifyDescription") Then
			ExecuteNotifyProcessing(CompletionProcessing, Undefined);
		EndIf;
		Return;
	EndIf;
	
	StandardSubsystemsClient.SetFormStorage(Form, True);
	
	Context = New Structure;
	Context.Insert("Form", Form);
	Context.Insert("CompletionProcessing", CompletionProcessing);
	Context.Insert("ClientParameters", ClientParameters);
	Context.Insert("Notification", New NotifyDescription("ExtendOperationContextStorage", ThisObject));
	
	If TypeOf(CompletionProcessing) = Type("NotifyDescription") Then
		Form.OnCloseNotifyDescription = New NotifyDescription(
			"OpenNewFormClosingAlert", ThisObject, Context);
	EndIf;
	
	Notification = New NotifyDescription("OpenNewFormContinue", ThisObject, Context);
	
	If ClientParameters = Undefined Then
		Form.ContinueOpen(Notification, CommonInternalData);
	Else
		Form.ContinueOpen(Notification, CommonInternalData, ClientParameters);
	EndIf;
	
EndProcedure

// Continue the procedure OpenNewForm.
&AtClient
Procedure OpenNewFormContinue(Result, Context) Export
	
	If Context.Form.IsOpen() Then
		Return;
	EndIf;
	
	UpdateFormStorage(Context);
	
	If TypeOf(Context.CompletionProcessing) = Type("NotifyDescription") Then
		ExecuteNotifyProcessing(Context.CompletionProcessing, Result);
	EndIf;
	
EndProcedure

// Continue the procedure OpenNewForm.
&AtClient
Procedure OpenNewFormClosingAlert(Result, Context) Export
	
	UpdateFormStorage(Context);
	
	If TypeOf(Context.CompletionProcessing) = Type("NotifyDescription") Then
		ExecuteNotifyProcessing(Context.CompletionProcessing, Result);
	EndIf;
	
EndProcedure

&AtClient
Procedure UpdateFormStorage(Context)
	
	StandardSubsystemsClient.SetFormStorage(Context.Form, False);
	
	If TypeOf(Context.ClientParameters) = Type("Structure")
	   AND Context.ClientParameters.Property("DataDescription")
	   AND TypeOf(Context.ClientParameters.DataDescription) = Type("Structure")
	   AND Context.ClientParameters.DataDescription.Property("OperationContext")
	   AND TypeOf(Context.ClientParameters.DataDescription.OperationContext) = Type("ManagedForm") Then
	
	#If WebClient Then
		ExtendOperationContextStorage(Context.ClientParameters.DataDescription.OperationContext);
	#EndIf
	EndIf;
	
EndProcedure

&AtClient
Procedure ExtendOperationContextStorage(Form) Export
	
	If TypeOf(Form) = Type("ManagedForm") Then
		OperationsContextsTemporaryStorage.Insert(Form,
			New Structure("Form, Time", Form, CommonUseClient.SessionDate()));
	EndIf;
	
EndProcedure

&AtClient
Procedure DeleteOutdatedOperationsContexts()
	
	DeletedLinksToForms = New Array;
	For Each KeyAndValue IN OperationsContextsTemporaryStorage Do
		
		If KeyAndValue.Value.Form.IsOpen() Then
			OperationsContextsTemporaryStorage[KeyAndValue.Key].Time = CommonUseClient.SessionDate();
			
		ElsIf KeyAndValue.Value.Time + 15*60 < CommonUseClient.SessionDate() Then
			DeletedLinksToForms.Add(KeyAndValue.Key);
		EndIf;
	EndDo;
	
	For Each Form IN DeletedLinksToForms Do
		OperationsContextsTemporaryStorage.Delete(Form);
	EndDo;
	
EndProcedure

&AtClient
Procedure SetCertificatePassword(CertificatRef, Password, PasswordExplanation) Export
	
	SetPasswords = CommonInternalData.Get("SetPasswords");
	SetPasswordsExplanations = CommonInternalData.Get("SetPasswordsExplanations");
	
	If SetPasswords = Undefined Then
		SetPasswords = New Map;
		CommonInternalData.Insert("SetPasswords", SetPasswords);
		SetPasswordsExplanations = New Map;
		CommonInternalData.Insert("SetPasswordsExplanations", SetPasswordsExplanations);
	EndIf;
	
	ContinuationProcessor = New NotifyDescription("SetCertificatePassword", ThisObject);
	
	SetPasswords.Insert(CertificatRef, String(Password));
	Password = Undefined;
	
	NewPasswordExplanation = New Structure;
	NewPasswordExplanation.Insert("ExplanationText", "");
	NewPasswordExplanation.Insert("ExplanationHyperlink", False);
	NewPasswordExplanation.Insert("ToolTipText", "");
	NewPasswordExplanation.Insert("ActionProcessing", Undefined);
	
	If TypeOf(PasswordExplanation) = Type("Structure") Then
		FillPropertyValues(NewPasswordExplanation, PasswordExplanation);
	EndIf;
	
	SetPasswordsExplanations.Insert(CertificatRef, NewPasswordExplanation);
	
EndProcedure

#EndRegion
