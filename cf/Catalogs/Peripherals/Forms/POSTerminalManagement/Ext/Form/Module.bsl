
#Region FormCommandsHandlers

&AtClient
Procedure PreliminaryOperationAuthorizationEnd(Result, Parameters) Export
	 
	FormParameters = New Structure;
	If Parameters.Property("SpecifyAdditionalInformation") Then
		FormParameters.Insert("SpecifyAdditionalInformation", True);
	EndIf;
	
	If Parameters.Property("AmountEditingProhibition") Then
		FormParameters.Insert("AmountEditingProhibition", Parameters.AmountEditingProhibition);
	EndIf;
	
	If Parameters.Property("OperationKind") Then
		Result.Insert("OperationKind", Parameters.OperationKind);
	EndIf;
	
	If Parameters.Property("WithoutReturnedParameters") Then
		Result.Insert("WithoutReturnedParameters", Parameters.WithoutReturnedParameters);
	EndIf;
	
	If Parameters.Property("SpecifyRefNo") Then
		Result.Insert("SpecifyRefNo", Parameters.SpecifyRefNo);
	EndIf;
	
	NotifyDescription = New NotifyDescription(Parameters.DataProcessorAlert, ThisObject, Result);
	OpenForm("Catalog.Peripherals.Form.POSTerminalAuthorizationForm", FormParameters,,,  ,, NotifyDescription, FormWindowOpeningMode.LockWholeInterface);
	
EndProcedure

&AtClient
Procedure ExecuteOperationByPaymentCardEnd(Result, Parameters) Export
	
	If TypeOf(Result) = Type("Structure") Then
		
		If Not Parameters.Property("OperationKind") Then
			MessageText = NStr("en='Transaction type is not specified.';ru='Не указан тип транзакции.'");
			CommonUseClientServer.MessageToUser(MessageText);
			Return;
		EndIf;
		
		InputParameters  = New Array();
		Output_Parameters = Undefined;
		
		SlipReceiptText  = "";
		AmountOfOperations  = Result.Amount;
		ReceiptNumber      = Result.ReceiptNumber;
		CardData    = Result.CardData;
		RefNo = Result.RefNo;
		
		InputParameters.Add(AmountOfOperations);
		InputParameters.Add(CardData);
		If Parameters.Property("SpecifyRefNo") Then
			InputParameters.Add(RefNo);
			InputParameters.Add(ReceiptNumber);
		Else
			InputParameters.Add(ReceiptNumber);
			InputParameters.Add(RefNo);
		EndIf;
		
		// Executing the operation on POS terminal.
		ResultET = EquipmentManagerClient.RunCommand(Parameters.EnabledDeviceIdentifierET, Parameters.OperationKind, InputParameters, Output_Parameters);
		
		If Not ResultET Then
			MessageText = NStr("en='When operation execution there
		|was error: ""%ErrorDescription%"".
		|Operation by card was not made.';ru='При выполнении операции возникла ошибка:
		|""%ОписаниеОшибки%"".
		|Отмена по карте не была произведена'");
			MessageText = StrReplace(MessageText, "%ErrorDescription%", Output_Parameters[1]);
			CommonUseClientServer.MessageToUser(MessageText);
		Else
			
			If Parameters.Property("WithoutReturnedParameters") Then
				CardNumber          = "";
				OperationRefNumber = "";
				ReceiptNumber           = "";
				SlipReceiptText       = Output_Parameters[0][1];
			Else
				CardNumber            = Output_Parameters[0];
				OperationRefNumber    = Output_Parameters[1];
				ReceiptNumber         = Output_Parameters[2];
				SlipReceiptText       = Output_Parameters[3][1];
			EndIf;
			
			If Not IsBlankString(SlipReceiptText) Then
				glPeripherals.Insert("LastSlipReceipt", SlipReceiptText);
			EndIf;
			
			ResultFR = True;
			
			If Not Parameters.ReceiptsPrintOnTerminal AND Not Parameters.FREnableDeviceID = Undefined Then
				If Not IsBlankString(SlipReceiptText) Then
					InputParameters = New Array();
					InputParameters.Add(SlipReceiptText);
					Output_Parameters = Undefined;
					ResultFR = EquipmentManagerClient.RunCommand(Parameters.FREnableDeviceID, "PrintText", InputParameters, Output_Parameters);
				EndIf;
			EndIf;
			
			If ResultET AND Not ResultFR Then
				ErrorDescriptionFR  = Output_Parameters[1];
				InputParameters  = New Array();
				
				Output_Parameters = Undefined;
				InputParameters.Add(AmountOfOperations);
				InputParameters.Add(OperationRefNumber);
				InputParameters.Add(ReceiptNumber);
				// Executing the operation on POS terminal
				EquipmentManagerClient.RunCommand(Parameters.EnabledDeviceIdentifierET, "EmergencyVoid", InputParameters, Output_Parameters);
				
				MessageText = NStr("en='An error occurred while printing
		|a slip receipt: ""%ErrorDetails%"".
		|Operation by card has been cancelled.';ru='При печати слип чека
		|возникла ошибка: ""%ОписаниеОшибки%"".
		|Операция по карте была отменена.'");
				MessageText = StrReplace(MessageText, "%ErrorDescription%", ErrorDescriptionFR);
				CommonUseClientServer.MessageToUser(MessageText);
			Else
				MessageText = NStr("en='Operation has been successfully installed.';ru='Операция выполнена успешно.'");
				CommonUseClientServer.MessageToUser(MessageText);
			EndIf;
			
		EndIf;
		
	EndIf;
	
	EquipmentManagerClient.DisablePOSTerminal(UUID, Parameters);
	
EndProcedure

&AtClient
Procedure PayByPaymentCard(Command)
	
	ClearMessages();
	
	Context = New Structure;
	Context.Insert("DataProcessorAlert"         , "ExecuteOperationByPaymentCardEnd");
	Context.Insert("OperationKind"               , "AuthorizeSales");
	Context.Insert("SpecifyAdditionalInformation" , True);

	NotifyDescription = New NotifyDescription("PreliminaryOperationAuthorizationEnd", ThisObject, Context);
	EquipmentManagerClient.StartEnablePOSTerminal(NOTifyDescription, UUID);

EndProcedure

&AtClient
Procedure ReturnPaymentByCard(Command)
	
	ClearMessages();
	
	Context = New Structure;
	Context.Insert("DataProcessorAlert"           , "ExecuteOperationByPaymentCardEnd");
	Context.Insert("OperationKind"                , "AuthorizeRefund");
	Context.Insert("SpecifyAdditionalInformation" , True);
	Context.Insert("SpecifyRefNo"                 , True);
	NotifyDescription = New NotifyDescription("PreliminaryOperationAuthorizationEnd", ThisObject, Context);
	EquipmentManagerClient.StartEnablePOSTerminal(NOTifyDescription, UUID);
	
EndProcedure

&AtClient
Procedure CancelPaymentByCard(Command)
	
	ClearMessages();
	
	Context = New Structure;
	Context.Insert("DataProcessorAlert"           , "ExecuteOperationByPaymentCardEnd");
	Context.Insert("OperationKind"                , "AuthorizeVoid");
	Context.Insert("SpecifyAdditionalInformation" , True);
	Context.Insert("WithoutReturnedParameters"    , True);
	NotifyDescription = New NotifyDescription("PreliminaryOperationAuthorizationEnd", ThisObject, Context);
	EquipmentManagerClient.StartEnablePOSTerminal(NOTifyDescription, UUID);
	
EndProcedure

&AtClient
Procedure RunTotalsRevision(Command)
	
	ClearMessages();
	
	EquipmentManagerClient.RunTotalsOnPOSTerminalRevision(UUID);
	
EndProcedure

&AtClient
Procedure RunPreauthorization(Command)
	
	ClearMessages();
	
	Context = New Structure;
	Context.Insert("DataProcessorAlert"  , "ExecuteOperationByPaymentCardEnd");
	Context.Insert("OperationKind"       , "AuthorizePreSales");
	NotifyDescription = New NotifyDescription("PreliminaryOperationAuthorizationEnd", ThisObject, Context);
	EquipmentManagerClient.StartEnablePOSTerminal(NOTifyDescription, UUID);
	
EndProcedure

&AtClient
Procedure FinishPreauthorization(Command)
	
	ClearMessages();
	
	Context = New Structure;
	Context.Insert("DataProcessorAlert"           , "ExecuteOperationByPaymentCardEnd");
	Context.Insert("OperationKind"                , "AuthorizeCompletion");
	Context.Insert("WithoutReturnedParameters"    , "WithoutReturnedParameters"); 
	Context.Insert("SpecifyAdditionalInformation" , True);
	NotifyDescription = New NotifyDescription("PreliminaryOperationAuthorizationEnd", ThisObject, Context);
	EquipmentManagerClient.StartEnablePOSTerminal(NOTifyDescription, UUID);
	
EndProcedure

&AtClient
Procedure CancelPreauthorization(Command)
	
	ClearMessages();
	
	Context = New Structure;
	Context.Insert("DataProcessorAlert"          , "ExecuteOperationByPaymentCardEnd");
	Context.Insert("OperationKind"                , "AuthorizeVoidPreSales");
	Context.Insert("WithoutReturnedParameters"    , "WithoutReturnedParameters");
	Context.Insert("SpecifyAdditionalInformation" , True);
	NotifyDescription = New NotifyDescription("PreliminaryOperationAuthorizationEnd", ThisObject, Context);
	EquipmentManagerClient.StartEnablePOSTerminal(NOTifyDescription, UUID);
	
EndProcedure

&AtClient
Procedure PrintLastSlipReceiptEnd(DeviceIdentifier, Parameters) Export
	
	ErrorDescription = "";
	
	// FR device connection
	ResultFR = EquipmentManagerClient.ConnectEquipmentByID(UUID, DeviceIdentifier, ErrorDescription);
	
	If ResultFR Then
		
		If Not IsBlankString(glPeripherals.LastSlipReceipt) Then
			InputParameters = New Array();
			InputParameters.Add(glPeripherals.LastSlipReceipt);
			Output_Parameters = Undefined;
			
			ResultFR = EquipmentManagerClient.RunCommand(DeviceIdentifier, "PrintText", InputParameters, Output_Parameters);
			If Not ResultFR Then
				MessageText = NStr("en='When document printing there
		|is error: ""%ErrorDescription%"".';ru='При печати документа произошла ошибка:
		|""%ОписаниеОшибки%"".'");
				MessageText = StrReplace(MessageText, "%ErrorDescription%", Output_Parameters[1]);
				CommonUseClientServer.MessageToUser(MessageText);
			EndIf;
		Else
			MessageText = NStr("en='There is no last slip receipt.';ru='Отсутствует последний слип чек.'");
			CommonUseClientServer.MessageToUser(MessageText);
		EndIf;
		// FR device disconnect
		EquipmentManagerClient.DisableEquipmentById(UUID, DeviceIdentifier);
		
	Else
		MessageText = NStr("en='An error occurred while connecting
		|the fiscal register: ""%ErrorDescription%"".';ru='При подключении фискального регистратора произошла ошибка: ""%ОписаниеОшибки%"".'");
		MessageText = StrReplace(MessageText, "%ErrorDescription%", ErrorDescription);
		CommonUseClientServer.MessageToUser(MessageText);
	EndIf;
	
EndProcedure

&AtClient
Procedure PrintLastSlipReceipt(Command)
	
	ClearMessages();
	
	NotifyDescription = New NotifyDescription("PrintLastSlipReceiptEnd", ThisObject, Parameters);
	EquipmentManagerClient.OfferSelectDevice(NOTifyDescription, "FiscalRegister",
			NStr("en='Select a fiscal register to print POS receipts.';ru='Выберите фискальный регистратор для печати эквайринговых чеков'"), 
			NStr("en='Fiscal register for printing acquiring receipts is not enabled.';ru='Фискальный регистратор для печати эквайринговых чеков не подключен.'"));
			
EndProcedure

#EndRegion













