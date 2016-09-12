////////////////////////////////////////////////////////////////////////////////
// Open secondary forms
//  
////////////////////////////////////////////////////////////////////////////////


#Region ProgramInterface

// Instruction
Procedure OpenServiceManual(StandardProcessing = False) Export
	
	StandardProcessing = False;
	OpenForm("DataProcessor.InstructionOnUsageCounterpartiesCheck.Form.InstructionOnCheckingCounterparties", , , "Instruction");
	
EndProcedure

// Settings
Procedure OpenServiceSettings() Export
	
	OpenForm("CommonForm.CounterpartyVerificationsSetting");

EndProcedure

// Processing interval of the background job result
Procedure RecalculateCheckResultInterval(CheckResultInterval) Export
	
	If CheckResultInterval < 5 Then
		CheckResultInterval = CheckResultInterval + 1;
	Else
		CheckResultInterval = 5;
	EndIf;

EndProcedure

Procedure WarnAboutInactiveCounterpartiesPresence(Form, DocumentObject, WriteParameters, Cancel) Export
	
	If Form.UseChecksAllowed Then
		
		If Form.IsProgramRecord Then
			If Form.CancelCounterpartiesCheck Then
				Cancel = True;
			EndIf;
			Form.IsProgramRecord = False;
		Else
			
			AdditionalParameters = New Structure;
			AdditionalParameters.Insert("WriteParameters", WriteParameters);
			AdditionalParameters.Insert("Form", 			Form);
			NotifyDescription = New NotifyDescription("ProcessUserResponseToWarning", CounterpartiesCheckClient, AdditionalParameters);
			
			If Not Cancel 
				AND WriteParameters.Property("WriteMode") 
				AND WriteParameters.WriteMode = DocumentWriteMode.Posting Then
				
				HasInactiveCounterparties 	= False;
				InactiveCounterparties 		= New Array;
				FinalState 				= Undefined;
				
				CounterpartiesCheckClientOverridable.GetInvalidCounterpartyPresence(
					Form, DocumentObject, HasInactiveCounterparties, InactiveCounterparties, FinalState);
				
				// Ask question
				If HasInactiveCounterparties Then
					
					Cancel = True;
					
					QuestionText = WarningTextOnInactiveCounterparties(InactiveCounterparties, FinalState);
											
					Buttons = New ValueList;
					Buttons.Add(DialogReturnCode.Yes, 	"Continue");
					Buttons.Add(DialogReturnCode.No, "Cancel");
					
					DefaultButton = Buttons.Get(1).Value;

					ShowQueryBox(NOTifyDescription, QuestionText, Buttons, , DefaultButton);
					
				Else
					ExecuteNotifyProcessing(NOTifyDescription, DialogReturnCode.Yes);
				EndIf;
			Else
				ExecuteNotifyProcessing(NOTifyDescription, DialogReturnCode.Yes);
			EndIf;
		EndIf;
		
	EndIf;
	
EndProcedure

Procedure ResetReportActuality(Form) Export
	
	CommonUseClientServer.SetSpreadsheetDocumentFieldState(Form.Items.Result, "NotActuality");
	CounterpartiesCheckClientServer.ChangePanelKindCounterpartiesChecks(Form);

EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

Function WarningTextOnInactiveCounterparties(InactiveCounterparties, FinalState)
	
	Substrings = New Array;
	If InactiveCounterparties.Count() = 1 Then
		
		// Text for one counterparty 
		
		Counterparty = String(InactiveCounterparties[0]);
		If FinalState = PredefinedValue("Enum.CounterpartyExistenceStates.KKPDoesNotMeetTIN") Then
			Substrings.Add(NStr("en=""Counterparty's KPP "";ru='КПП контрагента '"));
			Substrings.Add(Counterparty);
			Substrings.Add(NStr("en=' does nor correspond to the data of FTS base';ru=' не соответствует данным базы ФНС'"));
		ElsIf FinalState = PredefinedValue("Enum.CounterpartyExistenceStates.NotAvailableInRegistry") Then
			Substrings.Add(NStr("en='Counterparty ';ru='Контрагент '"));
			Substrings.Add(Counterparty);
			Substrings.Add(NStr("en=' not in FTS base';ru=' отсутствует в базе ФНС'"));
		ElsIf FinalState = PredefinedValue("Enum.CounterpartyExistenceStates.ContainsErrorsInData") Then
			Substrings.Add(NStr("en='Counterparty ';ru='Контрагент '"));
			Substrings.Add(Counterparty);
			Substrings.Add(NStr("en=' contains errors in TIN/KPP';ru=' содержит ошибки в заполнении ИНН/КПП'"));
		ElsIf FinalState = PredefinedValue("Enum.CounterpartyExistenceStates.ActivitiesDissolved") Then
			Substrings.Add(NStr("en='According to FTS counterparty ';ru='По данным ФНС контрагент '"));
			Substrings.Add(Counterparty);
			Substrings.Add(NStr("en=' stopped activity or changed KPP';ru=' прекратил деятельность или изменил КПП'"));
		Else
			Substrings.Add(NStr("en='Counterparty ';ru='Контрагент '"));
			Substrings.Add(Counterparty);
			Substrings.Add(NStr("en=' not valid by the document date';ru='недействителен на дату документа'"));
		EndIf;

		Substrings.Add(Chars.LF);
		Substrings.Add(CounterpartiesCheckClientServer.RefForInstruction());
		
	Else
		
		// Text for several counterparties
		
		Substrings.Add(NStr("en='According to FTS, the following counterparties are not valid by the document date:';ru='По данным ФНC следующие контрагенты недействительны на дату документа:'"));
		For Each InvalidCounterparty IN InactiveCounterparties Do
			Substrings.Add(Chars.LF);
			Substrings.Add("- ");
			Substrings.Add(String(InvalidCounterparty));
		EndDo;
		
		Substrings.Add(Chars.LF);
		Substrings.Add(CounterpartiesCheckClientServer.RefForInstruction());
		
	EndIf;
	
	WarningText = New FormattedString(Substrings);
	
	Return WarningText;
		
EndFunction

Procedure ProcessUserResponseToDoMessageBox(Response, AdditionalParameters) Export
	
	WriteParameters = AdditionalParameters.WriteParameters;
	Form 			= AdditionalParameters.Form;
	
	UserCanceledWrite = Response = DialogReturnCode.No;
	
	Form.CancelCounterpartiesCheck = UserCanceledWrite;
	Form.IsProgramRecord 		= Not UserCanceledWrite;
	
	If Not UserCanceledWrite Then
		
		// Continue posting (and if needed unlocking and closing)
		Form.ContinueWriteDocument(WriteParameters);
		
	EndIf;
	
EndProcedure

#EndRegion
