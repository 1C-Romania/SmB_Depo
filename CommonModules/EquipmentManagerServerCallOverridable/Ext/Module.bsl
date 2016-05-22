
#Region ProgramInterface

// Returns available equipment types list
//
Function GetAvailableEquipmentTypes() Export
	
	EquipmentList = New Array;

	// Bar code scanners
	EquipmentList.Add(Enums.PeripheralTypes.BarCodeScanner);
	// End Barcode scanners

	// Magnetic card readers
	EquipmentList.Add(Enums.PeripheralTypes.MagneticCardReader);
	// End Mangnet cards reader

	// Fiscal cash registers
	EquipmentList.Add(Enums.PeripheralTypes.FiscalRegister);
	// End Fiscal resgisters

	// Customer displays
	EquipmentList.Add(Enums.PeripheralTypes.CustomerDisplay);
	// End Customners displays

	// Data collection terminals
	EquipmentList.Add(Enums.PeripheralTypes.DataCollectionTerminal);
	// End Data collection terminals

	// POS terminals
	EquipmentList.Add(Enums.PeripheralTypes.POSTerminal);
    // End POS terminals
	
	// Electronic scales
	EquipmentList.Add(Enums.PeripheralTypes.ElectronicScales);
	// End Electronuc scales

	// Labels printing scales
	EquipmentList.Add(Enums.PeripheralTypes.LabelsPrintingScales);
	// End Scales with label printing

	// CR offline
	EquipmentList.Add(Enums.PeripheralTypes.CashRegistersOffline);
	// End CR offline
	
	Return EquipmentList;
	
EndFunction

// Returns availability flag for new drivers to the drivers catalog.
//
Function PossibilityToAddNewDrivers() Export
	
	YouCanAddNewDrivers = True;
	Return YouCanAddNewDrivers;
	
EndFunction

// Returns the flag showing that it is possible to call the separated data from the current session.
// Returns True if there is a call in the undivided configuration.
//
// Returns:
// Boolean.
//
Function CanUseSeparatedData() Export
	
	Return CommonUseReUse.CanUseSeparatedData();
	
EndFunction

// Update supplied drivers within the configuration
//                                   
Procedure RefreshSuppliedDrivers() Export
	
	// Bar code scanners
	Catalogs.HardwareDrivers.FillPredefinedItem(Enums.PeripheralDriverHandlers.HandlerScancodeBarCodeScanners, "AddIn.ScancodeScanner", "DriverScancodeBarCodeScanners", True);
	Catalogs.HardwareDrivers.FillPredefinedItem(Enums.PeripheralDriverHandlers.HandlerAtolBarCodeScanners, "AddIn.Scaner45", , True);
	Catalogs.HardwareDrivers.FillPredefinedItem(Enums.PeripheralDriverHandlers.Handler1CBarCodeScanners, "AddIn.Scanner", "DriverBarCodeScanner1C", False);
	Catalogs.HardwareDrivers.FillPredefinedItem(Enums.PeripheralDriverHandlers.Handler1CBarCodeScannersNative, "AddIn.InputDevice", "DriverBarCodeScanner1CNative", False);
	Catalogs.HardwareDrivers.FillPredefinedItem(Enums.PeripheralDriverHandlers.HandlerHexagonBarCodeScanners, "AddIn.ProtonScanner", "DriverHexagonBarCodeScanners", False);	
	// End Barcode scanners
	
	// Magnetic card readers
	Catalogs.HardwareDrivers.FillPredefinedItem(Enums.PeripheralDriverHandlers.HandlerAtolMagneticCardReaders, "AddIn.Scaner45", , True);
	Catalogs.HardwareDrivers.FillPredefinedItem(Enums.PeripheralDriverHandlers.Handler1CMagneticCardReaders, "AddIn.Scanner", "DriverBarCodeScanner1C", False);
	// End Mangnet cards reader
	
	// Fiscal cash registers
	Catalogs.HardwareDrivers.FillPredefinedItem(Enums.PeripheralDriverHandlers.Handler1CFiscalRegistersEmulator, "AddIn.EmulatorFP1C", "Driver1CFiscalRegister", False);
	Catalogs.HardwareDrivers.FillPredefinedItem(Enums.PeripheralDriverHandlers.Handler1CRarusFiscalRegistersFelix, "AddIn.fr_feliksRMK1c82", "Driver1CRarusFiscalRegistersFelix", False);
	Catalogs.HardwareDrivers.FillPredefinedItem(Enums.PeripheralDriverHandlers.Handler1CRarusFiscalRegistersMobius, "AddIn.fr_moebius1c82", "Driver1CRarusFiscalRegistersMobius", False);
	Catalogs.HardwareDrivers.FillPredefinedItem(Enums.PeripheralDriverHandlers.HandlerAtolFiscalRegisters, "AddIn.ATOL_KKM_1C", , True);
	Catalogs.HardwareDrivers.FillPredefinedItem(Enums.PeripheralDriverHandlers.HandlerATOLFiscalRegistersUniversal, "AddIn.ATOL_KKM_1C82", "DriverATOLFiscalRegisters", False);
	Catalogs.HardwareDrivers.FillPredefinedItem(Enums.PeripheralDriverHandlers.HandlerATOLFiscalRegisters8X, "AddIn.ATOL_KKM_1C82", "DriverATOLFiscalRegisters8X", False);
	Catalogs.HardwareDrivers.FillPredefinedItem(Enums.PeripheralDriverHandlers.HandlerVersionTFiscalRegisters, "AddIn.KSBFR1K1C", "DriverVersionTFiscalRegisters", True);
	Catalogs.HardwareDrivers.FillPredefinedItem(Enums.PeripheralDriverHandlers.HandlerKKSFiscalRegisters, "AddIn.SparkTF", "DriverKKSFiscalRegisters", False);
	Catalogs.HardwareDrivers.FillPredefinedItem(Enums.PeripheralDriverHandlers.HandlerShtrikhMFiscalRegisters, "AddIn.DrvFR1C", , True);
	Catalogs.HardwareDrivers.FillPredefinedItem(Enums.PeripheralDriverHandlers.HandlerShtrikhMFiscalRegistersUniversal, "AddIn.SMDrvFR1C", "DriverShtrikhMFiscalRegisters", False);
	Catalogs.HardwareDrivers.FillPredefinedItem(Enums.PeripheralDriverHandlers.HandlerORIONFiscalRegisters, "AddIn.OrionFR_1C8", "DriverORIONFiscalRegisters", True);
	// End Fiscal resgisters
	
	// Customer displays
	Catalogs.HardwareDrivers.FillPredefinedItem(Enums.PeripheralDriverHandlers.HandlerATOLCustomerDisplays, "AddIn.Line45", , True);
	Catalogs.HardwareDrivers.FillPredefinedItem(Enums.PeripheralDriverHandlers.HandlerKKSCustomerDisplays, "AddIn.VFCD220E", "DriverKKSCustomerDisplays", False);
	Catalogs.HardwareDrivers.FillPredefinedItem(Enums.PeripheralDriverHandlers.HandlerScancodeCustomerDisplays, "AddIn.1CDSPPromag", "DriverScancodeCustomerDisplays", True);
	Catalogs.HardwareDrivers.FillPredefinedItem(Enums.PeripheralDriverHandlers.HandlerShtrikhMCustomerDisplays, "AddIn.LineDisplay", "DriverShtrikhMCustomerDisplays", True);
	// End Customners displays
	
	// Data collection terminals
	Catalogs.HardwareDrivers.FillPredefinedItem(Enums.PeripheralDriverHandlers.HandlerAtolDataCollectionTerminals, "AddIn.PDX45", , True);
	Catalogs.HardwareDrivers.FillPredefinedItem(Enums.PeripheralDriverHandlers.HandlerHexagonDataCollectionTerminals, "AddIn.ProtonTSD", "DriverHexagonDataCollectionTerminals", False);
	Catalogs.HardwareDrivers.FillPredefinedItem(Enums.PeripheralDriverHandlers.HandlerScancodeDataCollectionTerminals, "AddIn.CipherLab", "DriverScancodeDCTCipherLab", True);
	Catalogs.HardwareDrivers.FillPredefinedItem(Enums.PeripheralDriverHandlers.HandlerScancityDataCollectionTerminals, "AddIn.iPOSoft_DT", "DriverScancityTCDCipherLab", True);
	Catalogs.HardwareDrivers.FillPredefinedItem(Enums.PeripheralDriverHandlers.HandlerKleverensDataCollectionTerminals, "AddIn.Cleverence.TO_TSD", "DriverKleverensDataCollectionTerminals", False);
	Catalogs.HardwareDrivers.FillPredefinedItem(Enums.PeripheralDriverHandlers.HandlerShtrikhMDataCollectionTerminals, "AddIn.Terminals", "DriverShtrikhMTCD", True);
	Catalogs.HardwareDrivers.FillPredefinedItem(Enums.PeripheralDriverHandlers.HandlerAtolDataCollectionTerminalsMobileLogistics, "AddIn.PDX1C_Int", "DriverATOLTSDMobileLogistics", False);
	// End Data collection terminals
	
	// POS terminals
	Catalogs.HardwareDrivers.FillPredefinedItem(Enums.PeripheralDriverHandlers.HandlerINPASPOSTerminalsSmart, "AddIn.a_inpas1c82", "DriverINPASPOSTerminalsSmart", False);
	Catalogs.HardwareDrivers.FillPredefinedItem(Enums.PeripheralDriverHandlers.HandlerINPASPOSTerminalsUNIPOS, "AddIn.a_inpasDC1c83", "DriverINPASPOSTerminalsUNIPOS", False);
	Catalogs.HardwareDrivers.FillPredefinedItem(Enums.PeripheralDriverHandlers.HandlerTRPOSPOSTerminals, "AddIn.a_trpos1c82", "DriverTRPOSPOSTerminals", False);
	Catalogs.HardwareDrivers.FillPredefinedItem(Enums.PeripheralDriverHandlers.HandlerPrivatBankPOSTerminals, "AddIn.a_ingenicopb1c82", "DriverPrivatBankPOSTerminals", False);
	Catalogs.HardwareDrivers.FillPredefinedItem(Enums.PeripheralDriverHandlers.HandlerSBRFPOSTerminals, "AddIn.SBRFCOMObject|AddIn.SBRFCOMExtension", "DriverSBRFPOSTerminals", True);
	Catalogs.HardwareDrivers.FillPredefinedItem(Enums.PeripheralDriverHandlers.HandlerUCSEFTPOSPOSTerminals, "AddIn.UCS_EFTPOS", "DriverUCSEFTPOSPOSTerminals", False);
	Catalogs.HardwareDrivers.FillPredefinedItem(Enums.PeripheralDriverHandlers.HandlerGAZPROMBANKPOSTerminals, "AddIn.GPBEMVGateNativeAPI1C", "DriverGAZPROMBANKPOSTerminals", False);
	Catalogs.HardwareDrivers.FillPredefinedItem(Enums.PeripheralDriverHandlers.HandlerINPASPOSTerminalsPulsar, "AddIn.AddInPulsarDriver1C", , True);
	Catalogs.HardwareDrivers.FillPredefinedItem(Enums.PeripheralDriverHandlers.HandlerSoftCasePOSTerminals, "AddIn.SKAM", , True);
	// End POS terminals                                                                         
	
	// Electronic scales
	Catalogs.HardwareDrivers.FillPredefinedItem(Enums.PeripheralDriverHandlers.HandlerATOLElectronicScales, "AddIn.Scale45", , True);
	Catalogs.HardwareDrivers.FillPredefinedItem(Enums.PeripheralDriverHandlers.HandlerShtrikhMElectronicScales, "AddIn.Scale45", "DriverShtrikhMElectronicScales", True);
	Catalogs.HardwareDrivers.FillPredefinedItem(Enums.PeripheralDriverHandlers.HandlerCASElectronicScales, "AddIn.CasCentreSimpleScale", "DriverCASElectronicScales", False);
	// End Electronuc scales
	
	// Labels printing scales
	Catalogs.HardwareDrivers.FillPredefinedItem(Enums.PeripheralDriverHandlers.HandlerACOMLabelPrintingScales);
	Catalogs.HardwareDrivers.FillPredefinedItem(Enums.PeripheralDriverHandlers.HandlerShtrikhMLabelPrintingScales, "AddIn.DrvLP", "DriverShtrikhMLabelPrintingScales", True);    
	Catalogs.HardwareDrivers.FillPredefinedItem(Enums.PeripheralDriverHandlers.HandlerScaleCASLabelPrintingScales, "CL5000J.WrapperFor1C82|AddIn.CL5000JFor1C82", "DriverScaleCASLabelPrintingScales", True);
	// End Scales with label printing
	
	// CR offline                                                                                                                                                     
	Catalogs.HardwareDrivers.FillPredefinedItem(Enums.PeripheralDriverHandlers.HandlerATOLFiscalRegistersOffline);
	Catalogs.HardwareDrivers.FillPredefinedItem(Enums.PeripheralDriverHandlers.HandlerShtrikhMCashRegisterOffline);   
	// End CR offline
	
EndProcedure

// Updating the EquipmentDriver field in the peripherals list.
Procedure RefreshDriversConnectedEquipmentHandbook() Export
	      
	UpdateDriverRequired = False;
	DriverUpdateCompleted  = False;
	
	Query = New Query("SELECT
						  |Peripherals.Ref,
						  |Peripherals.DeleteDriverHandler
						  |FROM
						  |Catalog.Peripherals AS Peripherals");
	
	Selection = Query.Execute().Select();
				   
	While Selection.Next() Do
		
		Driver = Undefined;
		
		If Selection.DeleteDriverHandler = Enums.PeripheralDriverHandlers.HandlerScancodeBarCodeScanners
			Or Selection.DeleteDriverHandler = Enums.PeripheralDriverHandlers.Handler1CMagneticCardReaders Then
				UpdateDriverRequired = True;
		EndIf;
		
		TempItemName = EquipmentManagerServerCall.GetDriverParametersForProcessor(String(Selection.DeleteDriverHandler));
		
		If TempItemName.Property("Name") Then 
			NameTempDriver = StrReplace(TempItemName.Name, "Handler", "Driver");
			Try
				Driver = EquipmentManagerServerCall.PredefinedItem("Catalog.HardwareDrivers." + NameTempDriver);
			Except
			EndTry;
		EndIf;
		
		If Driver <> Undefined Then
			Peripherals = Selection.Ref.GetObject();
			// "1C:Barcode scanner" driver update required
			If UpdateDriverRequired AND Not DriverUpdateCompleted Then
				Peripherals.InstallationIsRequired = True;
				DriverUpdateCompleted = True;
			EndIf;
			Peripherals.HardwareDriver = Driver;
			Peripherals.Write();
		EndIf;
		
	EndDo;
	
EndProcedure

#EndRegion

#Region EquipmentOffline

// The function returns the goods sold by weight used to generate barcode.
// Used for loading to scales with printing labels
Function GetWeightProductPrefix(PeripheralsRef) Export
	
	Prefix = Undefined;
	Return Prefix;
	
EndFunction

// The function returns the prefix of piece goods used to generate barcode
// Used for loading to scales with printing labels
Function GetPieceProductPrefix(PeripheralsRef) Export
	
	Prefix = Undefined;
	Return Prefix;
	
EndFunction

#EndRegion

#Region WorkWithFormInstanceEquipment

// Additional redefined actions with controlled form
// in the Equipment instance for the OnCreateAtServer event
//
Procedure EquipmentInstanceOnCreateAtServer(Object, ThisForm, Cancel, Parameters, StandardProcessing) Export

EndProcedure

// Additional redefined actions with controlled form
// in the Equipment instance for "OnReadAtServer"
//
Procedure EquipmentInstanceOnReadAtServer(CurrentObject, ThisForm) Export

EndProcedure

// Additional  redefined actions with controlled form
// in the Equipment form for the BeforeRecordingOnServer event
//
Procedure EquipmentInstanceBeforeWriteAtServer(Cancel, CurrentObject, WriteParameters) Export

EndProcedure

// Additional  redefined actions with controlled form  in
// the Equipment instance for the OnWriteAtServer event
//
Procedure EquipmentInstanceOnWriteAtServer(Cancel, CurrentObject, WriteParameters) Export

EndProcedure

// Additional  redefined actions with controlled form
// in the Equipment instance for the AfterRecordedOnServer event
//
Procedure EquipmentInstanceAfterWriteAtServer(CurrentObject, WriteParameters) Export

EndProcedure

// Additional  redefined actions with controlled form
// in the Equipment instance for the ProcessingOnServerFillinCheck event
//
Procedure EquipmentInstanceFillCheckProcessingAtServer(Object, ThisForm, Cancel, CheckedAttributes) Export

EndProcedure

#EndRegion

#Region SupportCompatibility

// The function creates a node for this instance of peripherals and returns a link to it.
// Used before recording the element of the Peripherals catalog
Function GetDIBNode(PeripheralsObject) Export
	
	NodeObject = ExchangePlans.ExchangeWithPeripheralsOffline.CreateNode();
	NodeObject.SetNewCode();
	NodeObject.Description = PeripheralsObject.Description;
	NodeObject.Write();
	
	Return NodeObject.Ref;
	
EndFunction

#EndRegion
