
#Region ProgramInterface

// Returns the current date adjusted to the time zone of the session.
// It is intended to use instead of the function CurrentDate().
//
Function SessionDate() Export
	
	Return CurrentDate();
	
EndFunction

// Function returns the driver handler object by its description.
//
Function GetDriverHandler(DriverHandler, ImportedDriver) Export
	
	Result = Undefined;
	
	// If driver is loadable - use standard handler.
	If ImportedDriver Then
		Result = PeripheralsUniversalDriverClient;  
	EndIf;
	
	If DriverHandler <> Undefined Then
		
		// Bar code scanners
		If DriverHandler = PredefinedValue("Enum.PeripheralDriverHandlers.Handler1CBarCodeScanners") Then
			Return Peripherals1CBarcodeScannersClient;
		ElsIf DriverHandler = PredefinedValue("Enum.PeripheralDriverHandlers.Handler1CBarCodeScannersNative") Then
			Return PeripheralsUniversalDriverClientAsynchronously;
		ElsIf DriverHandler = PredefinedValue("Enum.PeripheralDriverHandlers.HandlerScancodeBarCodeScanners") Then
			Return PeripheralsScancodeBarcodeScannersClient;
		ElsIf DriverHandler = PredefinedValue("Enum.PeripheralDriverHandlers.HandlerAtolBarCodeScanners") Then
			Return PeripheralsAtolBarcodeScannersClient;
		ElsIf DriverHandler = PredefinedValue("Enum.PeripheralDriverHandlers.HandlerHexagonBarCodeScanners") Then
			Return PeripheralsUniversalDriverClient;
		EndIf;
		// End Barcode scanners
		
		// Magnetic card readers
		If DriverHandler = PredefinedValue("Enum.PeripheralDriverHandlers.Handler1CMagneticCardReaders") Then
			Return PeripheralsWithMagneticCardReaders1Client;
		ElsIf DriverHandler = PredefinedValue("Enum.PeripheralDriverHandlers.HandlerAtolMagneticCardReaders") Then
			Return PeripheralsAtolReadersMagneticCardClient;
		EndIf;
		// End Mangnetic cards readers.

		// Fiscal cash registers
		If DriverHandler = PredefinedValue("Enum.PeripheralDriverHandlers.Handler1CFiscalRegistersEmulator") Then
			Return PeripheralsUniversalDriverClient;
		ElsIf DriverHandler = PredefinedValue("Enum.PeripheralDriverHandlers.HandlerAtolFiscalRegisters") Then
			Return PeripheralsAtolFiscalRegistersClient;
		ElsIf DriverHandler = PredefinedValue("Enum.PeripheralDriverHandlers.HandlerATOLFiscalRegistersUniversal") Then
			Return PeripheralsUniversalDriverClient;
		ElsIf DriverHandler = PredefinedValue("Enum.PeripheralDriverHandlers.HandlerATOLFiscalRegisters8X") Then
			Return PeripheralsUniversalDriverClient;
		ElsIf DriverHandler = PredefinedValue("Enum.PeripheralDriverHandlers.HandlerVersionTFiscalRegisters") Then
			Return PeripheralsVersionTCashRegistersClient;
		ElsIf DriverHandler = PredefinedValue("Enum.PeripheralDriverHandlers.HandlerKKSFiscalRegisters") Then
			Return PeripheralsKKSCashRegistersClient;
		ElsIf DriverHandler = PredefinedValue("Enum.PeripheralDriverHandlers.HandlerShtrikhMFiscalRegisters") Then
			Return PeripheralsShtrikhMFiscalRegistersClient;
		ElsIf DriverHandler = PredefinedValue("Enum.PeripheralDriverHandlers.HandlerShtrikhMFiscalRegistersUniversal") Then
			Return PeripheralsUniversalDriverClient;
		ElsIf DriverHandler = PredefinedValue("Enum.PeripheralDriverHandlers.HandlerORIONFiscalRegisters") Then
			Return PeripheralsORIONFiscalRegistersClient;
		ElsIf DriverHandler = PredefinedValue("Enum.PeripheralDriverHandlers.Handler1CRarusFiscalRegistersFelix") Then
			Return PeripheralsUniversalDriverClient;
		ElsIf DriverHandler = PredefinedValue("Enum.PeripheralDriverHandlers.Handler1CRarusFiscalRegistersMobius") Then
			Return PeripheralsUniversalDriverClient;
		EndIf;
		// End Fiscal registers.

		// Customer displays
		If DriverHandler = PredefinedValue("Enum.PeripheralDriverHandlers.HandlerATOLCustomerDisplays") Then
			Return PeripheralsAtolCustomerDisplaysClient;
		ElsIf DriverHandler = PredefinedValue("Enum.PeripheralDriverHandlers.HandlerScancodeCustomerDisplays") Then
			Return PeripheralsScancodeCustomerDisplaysClient;
		ElsIf DriverHandler = PredefinedValue("Enum.PeripheralDriverHandlers.HandlerShtrikhMCustomerDisplays") Then
			Return PeripheralsShtrikhMCustomerDisplaysClient;
		ElsIf DriverHandler = PredefinedValue("Enum.PeripheralDriverHandlers.HandlerKKSCustomerDisplays") Then
			Return PeripheralsCCSKCustomerDisplaysClient;
		EndIf;                 
		// End Customners displays
		
		// Data collection terminals
		If DriverHandler = PredefinedValue("Enum.PeripheralDriverHandlers.HandlerAtolDataCollectionTerminals") Then
			Return PeripheralsAtolDataCollectionTerminalsClient;
		ElsIf DriverHandler = PredefinedValue("Enum.PeripheralDriverHandlers.HandlerShtrikhMDataCollectionTerminals") Then
			Return PeripheralsShtrikhMDataCollectionTerminalsClient;
		ElsIf DriverHandler = PredefinedValue("Enum.PeripheralDriverHandlers.HandlerScancodeDataCollectionTerminals") Then
			Return PeripheralsScancodeDataCollectionTerminalsClient;
		ElsIf DriverHandler = PredefinedValue("Enum.PeripheralDriverHandlers.HandlerScancityDataCollectionTerminals") Then
			Return PeripheralsScancityDataCollectionTerminalsClient;
		ElsIf DriverHandler = PredefinedValue("Enum.PeripheralDriverHandlers.HandlerKleverensDataCollectionTerminals") Then
			Return PeripheralsUniversalDriverClient;
		ElsIf DriverHandler = PredefinedValue("Enum.PeripheralDriverHandlers.HandlerHexagonDataCollectionTerminals") Then
			Return PeripheralsUniversalDriverClient;
		ElsIf DriverHandler = PredefinedValue("Enum.PeripheralDriverHandlers.HandlerAtolDataCollectionTerminalsMobileLogistics") Then
			Return PeripheralsUniversalDriverClient;
		EndIf;
		// End Data collection terminals.
		
		// POS terminals
		If DriverHandler = PredefinedValue("Enum.PeripheralDriverHandlers.HandlerSBRFPOSTerminals") Then
			Return PeripheralsSBRFPOSTerminalsClient;
		ElsIf DriverHandler = PredefinedValue("Enum.PeripheralDriverHandlers.HandlerINPASPOSTerminalsPulsar") Then
			Return PeripheralsINPASPulsarPOSTerminalsClient;
		ElsIf DriverHandler = PredefinedValue("Enum.PeripheralDriverHandlers.HandlerINPASPOSTerminalsSmart") Then
			Return PeripheralsINPASTerminalsSmartClient;
		ElsIf DriverHandler = PredefinedValue("Enum.PeripheralDriverHandlers.HandlerINPASPOSTerminalsUNIPOS") Then
			Return PeripheralsUniversalDriverClient;
		ElsIf DriverHandler = PredefinedValue("Enum.PeripheralDriverHandlers.HandlerSoftCasePOSTerminals") Then
			Return PeripheralsSoftCasePOSTerminalsClient;
		ElsIf DriverHandler = PredefinedValue("Enum.PeripheralDriverHandlers.HandlerTRPOSPOSTerminals") Then
			Return PeripheralsUniversalDriverClient;
		ElsIf DriverHandler = PredefinedValue("Enum.PeripheralDriverHandlers.HandlerPrivatBankPOSTerminals") Then
			Return PeripheralsUniversalDriverClient;
		ElsIf DriverHandler = PredefinedValue("Enum.PeripheralDriverHandlers.HandlerUCSEFTPOSPOSTerminals") Then
			Return PeripheralsUniversalDriverClient;
		ElsIf DriverHandler = PredefinedValue("Enum.PeripheralDriverHandlers.HandlerGAZPROMBANKPOSTerminals") Then
			Return PeripheralsUniversalDriverClient;
		EndIf;
		// End POS-Terminals.
		 
		// Electronic scales
		If DriverHandler = PredefinedValue("Enum.PeripheralDriverHandlers.HandlerATOLElectronicScales") Then
			Return PeripheralsAtolElectronicScalesClient;
		ElsIf DriverHandler = PredefinedValue("Enum.PeripheralDriverHandlers.HandlerShtrikhMElectronicScales") Then
			Return PeripheralsShtrikhMElectronicScalesClient;
		ElsIf DriverHandler = PredefinedValue("Enum.PeripheralDriverHandlers.HandlerCASElectronicScales") Then
			Return PeripheralsUniversalDriverClient;
		EndIf;
		// End Electronic scales
		
		// Labels printing scales
		If DriverHandler = PredefinedValue("Enum.PeripheralDriverHandlers.HandlerACOMLabelPrintingScales") Then
			Return PeripheralsACOMScalesWithLabelPrintingClient;
		ElsIf DriverHandler = PredefinedValue("Enum.PeripheralDriverHandlers.HandlerScaleCASLabelPrintingScales") Then
			Return PeripheralsScaleCASScalesWithLabelPrintingClient;
		ElsIf DriverHandler = PredefinedValue("Enum.PeripheralDriverHandlers.HandlerShtrikhMLabelPrintingScales") Then
			Return PeripheralsShtrikhMLabelPrintingScalesClient;
		EndIf;
		// End  Scales with label.
		
		// CR offline
		If DriverHandler = PredefinedValue("Enum.PeripheralDriverHandlers.HandlerATOLFiscalRegistersOffline") Then
			Return PeripheralsAtolCROfflineClient;
		ElsIf DriverHandler = PredefinedValue("Enum.PeripheralDriverHandlers.HandlerShtrikhMCashRegisterOffline") Then
			Return PeripheralsShtrikhMCROfflineClient;
		EndIf;
		// End CR offline
		
	EndIf;

	Return Result;
	
EndFunction

// Prints a fiscal receipt.
//
Function ReceiptPrint(EquipmentCommonModule, DriverObject, Parameters, ConnectionParameters, InputParameters, Output_Parameters, OutputMessageToUser = False) Export
	
	ProductsAndServicesTable = InputParameters[0];
	PaymentsTable        = InputParameters[1];
	CommonParameters      = InputParameters[2];
		                 
	Result  = True;
	// Open receipt
	Result = EquipmentCommonModule.OpenReceipt(DriverObject, Parameters, ConnectionParameters,
	                       CommonParameters[0] = 1, CommonParameters[1], Output_Parameters);

	// Print receipt rows   
	If Result Then
		ErrorOnLinePrinting = False;
		// Print receipt rows
		For ArrayIndex = 0 To ProductsAndServicesTable.Count() - 1 Do
			Description  = ProductsAndServicesTable[ArrayIndex][0].Value;
			Quantity    = ProductsAndServicesTable[ArrayIndex][5].Value;
			Price          = ProductsAndServicesTable[ArrayIndex][4].Value;
			DiscountPercent = ProductsAndServicesTable[ArrayIndex][8].Value;
			Amount         = ProductsAndServicesTable[ArrayIndex][9].Value;
			SectionNumber   = ProductsAndServicesTable[ArrayIndex][3].Value;
			VATRate     = ProductsAndServicesTable[ArrayIndex][12].Value;

			If Not EquipmentCommonModule.PrintFiscalLine(DriverObject, Parameters, ConnectionParameters,
											   Description, Quantity, Price, DiscountPercent, Amount,
											   SectionNumber, VATRate, Output_Parameters) Then
				ErrorOnLinePrinting = True;   
				Break;
			EndIf;
			
		EndDo;

		If Not ErrorOnLinePrinting Then
		  	// Close receipt
			Result = EquipmentCommonModule.CloseReceipt(DriverObject, Parameters, ConnectionParameters, PaymentsTable, Output_Parameters);	
		Else
			Result = False;
		EndIf;
		
	EndIf;

	Return Result;
	
EndFunction

#EndRegion

#Region WorkWithFormInstanceEquipment

// Additional overridable actions with handled form
// in the Equipment instance on "OnOpen" event.
//
Procedure EquipmentInstanceOnOpen(Object, ThisForm, Cancel) Export
	
EndProcedure

// Additional overridable actions with handled form
// in the Equipment instance on "BeforeClose" event.
//
Procedure EquipmentInstanceBeforeClose(Object, ThisForm, Cancel, StandardProcessing) Export
	
EndProcedure

// Additional overridable actions with handled form
// in the Equipment instance on "BeforeWrite" event.
//
Procedure EquipmentInstanceBeforeWrite(Object, ThisForm, Cancel, WriteParameters) Export
	
EndProcedure

// Additional overridable actions with handled form
// in the Equipment instance on "AfterWrite" event.
//
Procedure EquipmentInstanceAfterWrite(Object, ThisForm, WriteParameters) Export
	
EndProcedure

// Additional overridable actions with handled form
// in the Equipment instance on "EquipmentTypeChoiceProcessing" event.
//
Procedure EquipmentInstanceEquipmentTypeSelection(Object, ThisForm, ThisObject, Item, ValueSelected) Export
	
EndProcedure

#EndRegion

#Region EquipmentConnectionDisconnectionProcedures

// Start enabling required devices types during form opening
//
// Parameters:
// Form - ManagedForm
// SupportedPeripheralTypes - String
// 	Contains peripherals types list separated by commas.
//
Procedure StartConnectingEquipmentOnFormOpen(Form, SupportedPeripheralTypes) Export
	
	AlertOnConnect = New NotifyDescription("ConnectEquipmentEnd", EquipmentManagerClientOverridable);
	EquipmentManagerClient.StartConnectingEquipmentOnFormOpen(AlertOnConnect, Form, SupportedPeripheralTypes);
	
EndProcedure

Procedure ConnectEquipmentEnd(ExecutionResult, Parameters) Export
	
	If Not ExecutionResult.Result Then
		MessageText = NStr("en='An error occurred when connecting the equipment: ""%ErrorDetails%"".';ru='При подключении оборудования произошла ошибка:""%ОписаниеОшибки%"".'");
		MessageText = StrReplace(MessageText, "%ErrorDetails%" , ExecutionResult.ErrorDetails);
		CommonUseClientServer.MessageToUser(MessageText);
	EndIf;
	
EndProcedure

// Start disconnecting peripherals by type on closing the form.
//
Procedure StartDisablingEquipmentOnCloseForm(Form) Export
	
	AlertOnDisconnect = New NotifyDescription("DisableEquipmentEnd", EquipmentManagerClientOverridable); 
	EquipmentManagerClient.StartDisablingEquipmentOnCloseForm(AlertOnDisconnect, Form);
	
EndProcedure

&AtClient
Procedure DisableEquipmentEnd(ExecutionResult, Parameters) Export
	
	If Not ExecutionResult.Result Then
		MessageText = NStr("en='An error occurred when disconnecting the equipment: ""%ErrorDescription%"".';ru='При отключении оборудования произошла ошибка: ""%ОписаниеОшибки%"".'");
		MessageText = StrReplace(MessageText, "%ErrorDescription%" , ExecutionResult.ErrorDescription);
		CommonUseClientServer.MessageToUser(MessageText);
	EndIf;
	
EndProcedure

#EndRegion
