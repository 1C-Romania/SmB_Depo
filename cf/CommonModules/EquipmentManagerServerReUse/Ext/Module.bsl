
#Region ProgramInterface

// Function returns available types of peripherals connected to the workplace.
// 
Function TypesOfPeripheral() Export
	
	SetPrivilegedMode(True);
	Workplace = EquipmentManagerServerCall.GetClientWorkplace();
	
	If ValueIsFilled(Workplace) Then
		
		Query = New Query(
		"SELECT DISTINCT
		|	Peripherals.EquipmentType AS EquipmentType
		|FROM
		|	Catalog.Peripherals AS Peripherals
		|WHERE
		|	Peripherals.DeviceIsInUse
		|	AND Peripherals.Workplace = &Workplace");
		
		Query.SetParameter("Workplace", Workplace);
		
		Result = Query.Execute();
		Return Result.Unload().UnloadColumn("EquipmentType");
		
	Else
		Return Undefined;
	EndIf;
	
EndFunction

// Function connects external component and its original setting.
// Return value: UNDEFINED - failed to import the component.
Function ConnectBarcodePrintingExternalComponent() Export
	
	ConnectionCompleted = AttachAddIn("CommonTemplate.BarcodePrintingComponent", "BarCodePicture", AddInType.Native);
	
	// Create object of external component.
	If ConnectionCompleted Then
		ExternalComponent = New("AddIn.BarCodePicture.Barcode");
	Else
		Return Undefined;
	EndIf;
	
	// If it is not possible to draw.
	If Not ExternalComponent.GraphicsSet Then
		// That we won't be able to create image.
		Return Undefined;
	Else
		// Set the main component parameters.
		// If the Tahoma font is set in system.
		If ExternalComponent.FindFont("Tahoma") = True Then
			// Choose it as the font for image formation.
			ExternalComponent.Font = "Tahoma";
		Else
			// Tahoma font is not available in the system.
			// Search for all fonts available for the component.
			For Ct = 0 To ExternalComponent.FontsCount -1 Do
				// Get the next font available for component.
				CurrentFont = ExternalComponent.FontByIndex(Ct);
				// If the font is available
				If CurrentFont <> Undefined Then
					// This font will be selected for barcode formation.
					ExternalComponent.Font = CurrentFont;
					Break;
				EndIf;
			EndDo;
		EndIf;
		// Set the font size
		ExternalComponent.SizeOfFont = 12;
		
		Return ExternalComponent;
	EndIf;
	
EndFunction

#EndRegion