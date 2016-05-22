#Region ProgramInterface

#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

// The functions returns the list of activated peripherals in the catalog
//
Function GetEquipmentList(EETypes = Undefined, ID = Undefined, Workplace = Undefined) Export

	QueryText = "
	|SELECT
	|	Peripherals.Ref AS Ref,
	|	Peripherals.DeviceIdentifier AS DeviceIdentifier,
	|	Peripherals.Description AS Description,
	|	Peripherals.EquipmentType AS EquipmentType,
	|	Peripherals.HardwareDriver AS HardwareDriver,      
	|	Peripherals.Workplace AS Workplace,
	|	Peripherals.Parameters AS Parameters,
	|	Workplaces.ComputerName AS ComputerName
	|FROM
	|	Catalog.Peripherals AS Peripherals
	|		INNER JOIN Catalog.Workplaces AS Workplaces
	|		ON (Workplaces.Ref = Peripherals.Workplace)
	|WHERE
	|	(Peripherals.DeviceIsInUse)" +
		// We will add filters passed in the call parameters to the query text.
		?(ID = Undefined,
			// We will add filter by equipment types to the query text (if it is specified).
		  ?(EETypes <> Undefined,
		    "
		    |	AND (Peripherals.Workplace <> VALUE(Catalog.Workplaces.EmptyRef)) AND (Peripherals.EquipmentType IN (&EquipmentType)) AND (Workplaces.Ref = &Workplace)",
		    "
		    |	AND Workplaces.Ref = &Workplace"),
			// We will add filter by specific device to the query text (with priority over other filters).
		  "
		  |	   AND (Peripherals.Workplace <> VALUE(Catalog.Workplaces.EmptyRef)) And (Peripherals.Ref = &ID OR Peripherals.DeviceIdentifier = &ID)") +
	"
	|	AND (NOT Peripherals.DeletionMark)";
	
	// We will add the received filter condition to the query text.
	QueryText = QueryText + "
	|ORDER
	|	BY
	|	EquipmentType, Description;";

	Query = New Query(QueryText);
	
	// Set query parameters (filtering value sample).
	If ID = Undefined Then
		// Then the filter by workplace is used.
		If Not ValueIsFilled(Workplace) Then
			// If WP is not specified in parameters, then it is always the current of the session parameters.
			Workplace = EquipmentManagerServerCall.GetClientWorkplace();
		EndIf;

		Query.SetParameter("Workplace", Workplace);
		// And probably the filter by device types.
		If EETypes <> Undefined Then
			// Preparation of peripherals types enumeration for the query.
			ArrayTypesPE = New Array();
			If TypeOf(EETypes) = Type("Structure") Then
				For Each EEType IN EETypes Do
					ArrayTypesPE.Add(Enums.PeripheralTypes[EEType.Key]);
				EndDo;
				
			ElsIf TypeOf(EETypes) = Type("Array") Then
				For Each EEType IN EETypes Do
					ArrayTypesPE.Add(Enums.PeripheralTypes[EEType]);
				EndDo;
				
			Else
				ArrayTypesPE.Add(Enums.PeripheralTypes[EETypes]);
			EndIf;
			
			Query.SetParameter("EquipmentType", ArrayTypesPE);
		EndIf;
	Else // Filter by specific device.
		Query.SetParameter("ID", ID);
	EndIf;

	Selection = Query.Execute().Select();
	
	// Sorting the selection we compose the list of devices.
	EquipmentList = New Array();
	While Selection.Next() Do
		// Fill the device data structure.
		DataDevice = New Structure();
		DataDevice.Insert("Ref"                      , Selection.Ref);
		DataDevice.Insert("DeviceIdentifier"         , Selection.DeviceIdentifier); 
		DataDevice.Insert("Description"              , Selection.Description);
		DataDevice.Insert("EquipmentType"            , Selection.EquipmentType);
		DataDevice.Insert("EquipmentTypeName"        , EquipmentManagerServerCall.GetEquipmentTypeName(Selection.EquipmentType));
		DataDevice.Insert("HardwareDriver"           , Selection.HardwareDriver);
		DataDevice.Insert("HardwareDriverActualName" , Selection.HardwareDriver.PredefinedDataName);
		DataDevice.Insert("AsConfigurationPart"      , Selection.HardwareDriver.Predefined);
		DataDevice.Insert("ObjectID"                 , Selection.HardwareDriver.ObjectID);
		DataDevice.Insert("DriverHandler"            , Selection.HardwareDriver.DriverHandler);
		DataDevice.Insert("SuppliedAsDistribution"   , Selection.HardwareDriver.SuppliedAsDistribution);
		DataDevice.Insert("DriverTemplateName"       , Selection.HardwareDriver.DriverTemplateName);
		DataDevice.Insert("DriverFileName"           , Selection.HardwareDriver.DriverFileName);
		DataDevice.Insert("Parameters"               , Selection.Parameters.Get());
		DataDevice.Insert("Workplace"                , Selection.Workplace);
		DataDevice.Insert("ComputerName"             , Selection.ComputerName);
		If TypeOf(DataDevice.Parameters) = Type("Structure") Then
			DataDevice.Parameters.Insert("ID", Selection.Ref); 
		EndIf;
		EquipmentList.Add(DataDevice);
	EndDo;
	
	// Return a received list with data of all found devices.
	Return EquipmentList;
	
EndFunction

// The function returns the parameters of a device by its ID
//
Function GetDeviceParameters(ID) Export
	
	Query = New Query("
	|SELECT
	|	Peripherals.Parameters
	|FROM
	|	Catalog.Peripherals AS Peripherals
	|WHERE
	|	Peripherals.Ref = &ID OR
	|	Peripherals.DeviceIdentifier = &ID
	|");
	
	Query.SetParameter("ID", ID);
	Selection = Query.Execute().Select();
	Selection.Next();
	
	Result = Selection.Parameters.Get();
	Return Result;
	
EndFunction

// The procedure is designed for
// saving device parameters in the attribute: Parameters of storage type for value in the list item.
Function SaveDeviceParameters(ID, Parameters) Export

	Try
		Query = New Query("
		|SELECT
		|	Peripherals.Ref
		|FROM
		|	Catalog.Peripherals AS Peripherals
		|WHERE
		|	Peripherals.Ref = &ID OR
		|	Peripherals.DeviceIdentifier = &ID
		|");

		Query.SetParameter("ID", ID);
		TableOfResults = Query.Execute().Unload();

		CatalogObject = TableOfResults[0].Ref.GetObject();
		CatalogObject.Parameters = New ValueStorage(Parameters);
		CatalogObject.Write();

		Result = True;
	Except
		Result = False;
	EndTry;

	Return Result;

EndFunction

// Function returns a structure
// with device data (with values of catalog item attributes).
Function GetDeviceData(ID) Export

	DataDevice = New Structure();

	Query = New Query("
	|SELECT
	|	Peripherals.Ref AS Ref,
	|	Peripherals.DeviceIdentifier AS DeviceIdentifier,
	|	Peripherals.Description AS Description,
	|	Peripherals.EquipmentType AS EquipmentType,
	|	Peripherals.HardwareDriver AS HardwareDriver,      
	|	Peripherals.Workplace AS Workplace,
	|	Peripherals.Parameters AS Parameters,
	|	Workplaces.ComputerName AS ComputerName
	|FROM
	|	Catalog.Peripherals AS Peripherals
	|		LEFT JOIN Catalog.Workplaces AS Workplaces
	|		ON Peripherals.Workplace = Workplaces.Ref
	|WHERE
	|	(Peripherals.DeviceIdentifier = &ID
	|			OR Peripherals.Ref = &ID)
	|");
	
	Query.SetParameter("ID", ID);
	
	Selection = Query.Execute().Select();
	                                                           
	If Selection.Next() Then
		// Fill the device data structure.
		DataDevice.Insert("Ref"                      , Selection.Ref);
		DataDevice.Insert("DeviceIdentifier"         , Selection.DeviceIdentifier);
		DataDevice.Insert("Description"              , Selection.Description);
		DataDevice.Insert("EquipmentType"            , Selection.EquipmentType);
		DataDevice.Insert("EquipmentTypeName"        , EquipmentManagerServerCall.GetEquipmentTypeName(Selection.EquipmentType));
		DataDevice.Insert("HardwareDriver"           , Selection.HardwareDriver);
		DataDevice.Insert("HardwareDriverActualName" , Selection.HardwareDriver.PredefinedDataName);
		DataDevice.Insert("AsConfigurationPart"      , Selection.HardwareDriver.Predefined);
		DataDevice.Insert("ObjectID"                 , Selection.HardwareDriver.ObjectID);
		DataDevice.Insert("DriverHandler"            , Selection.HardwareDriver.DriverHandler);
		DataDevice.Insert("SuppliedAsDistribution"   , Selection.HardwareDriver.SuppliedAsDistribution);
		DataDevice.Insert("DriverTemplateName"       , Selection.HardwareDriver.DriverTemplateName);
		DataDevice.Insert("DriverFileName"           , Selection.HardwareDriver.DriverFileName);
		DataDevice.Insert("Parameters"               , Selection.Parameters.Get());
		DataDevice.Insert("Workplace"                , Selection.Workplace);
		DataDevice.Insert("ComputerName"             , Selection.ComputerName);
		If TypeOf(DataDevice.Parameters) = Type("Structure") Then
			DataDevice.Parameters.Insert("ID", Selection.Ref); 
		EndIf;
	EndIf;
		
	Return DataDevice;
	
EndFunction

#EndIf

#EndRegion