
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
	
	// End Barcode scanners
	
	// Magnetic card readers
	
	// End Mangnet cards reader
	
	// Fiscal cash registers
	
	// End Fiscal resgisters
	
	// Customer displays
	
	// End Customners displays
	
	// Data collection terminals
	
	// End Data collection terminals
	
	// POS terminals
	
	// End POS terminals                                                                         
	
	// Electronic scales
	
	// End Electronuc scales
	
	// Labels printing scales
	
	// End Scales with label printing
	
	// CR offline                                                                                                                                                     
	
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
