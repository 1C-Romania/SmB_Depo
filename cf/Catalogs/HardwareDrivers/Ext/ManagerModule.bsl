#Region ProgramInterface

#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

// Function restores a structure with
// data of hardware driver (with catalog item attributes values).
//
Function GetDriverData(ID) Export

	DriverData = New Structure();

	Query = New Query("
	|SELECT
	|	SpmHardwareDrivers.Ref,
	|	SpmHardwareDrivers.PredefinedDataName AS Name,
	|	SpmHardwareDrivers.EquipmentType AS EquipmentType,
	|	FALSE AS AsConfigurationPart,
	|	SpmHardwareDrivers.ObjectID AS ObjectID, 
	|	SpmHardwareDrivers.DriverHandler AS DriverHandler,
	|	SpmHardwareDrivers.SuppliedAsDistribution AS SuppliedAsDistribution, 
	|	SpmHardwareDrivers.ExportedDriver AS ExportedDriver,  
	|	SpmHardwareDrivers.DriverFileName  AS DriverFileName,  
	|	SpmHardwareDrivers.DriverTemplateName AS DriverTemplateName,
	|	SpmHardwareDrivers.DriverVersion    AS DriverVersion
	|FROM
	|	Catalog.HardwareDrivers AS SpmHardwareDrivers
	|WHERE
	|	 SpmHardwareDrivers.Ref = &ID");
	
	Query.SetParameter("ID", ID);
	
	Selection = Query.Execute().Select();
	                                                           
	If Selection.Next() Then
		// Fill the device data structure.
		DriverData.Insert("HardwareDriver"       , Selection.Ref);
		DriverData.Insert("HardwareDriverActualName"    , Selection.Name);
		DriverData.Insert("EquipmentType"           , Selection.EquipmentType);
		DriverData.Insert("AsConfigurationPart"      , Selection.AsConfigurationPart);
		DriverData.Insert("ObjectID"      , Selection.ObjectID);
		DriverData.Insert("DriverHandler"        , Selection.DriverHandler);
		DriverData.Insert("SuppliedAsDistribution" , Selection.SuppliedAsDistribution);
		DriverData.Insert("DriverTemplateName"         , Selection.DriverTemplateName);
		DriverData.Insert("DriverFileName"          , Selection.DriverFileName);
		DriverData.Insert("DriverVersion"            , Selection.DriverVersion);
	EndIf;
	
	Return DriverData;
	
	
EndFunction

Procedure FillPredefinedItem(DriverHandler, ObjectID = Undefined, DriverTemplateName = Undefined, SuppliedAsDistribution = False, DriverVersion = Undefined) Export
	
	//===============================
	//©# (Begin)	AlekS [2016-09-29]
	//If Metadata.CommonTemplates.Find(DriverTemplateName) = Undefined Then
	//	Return;
	//EndIf;
	//©# (End)		AlekS [2016-09-29]
	//===============================
	
	Parameters = EquipmentManagerServerCall.GetDriverParametersForProcessor(String(DriverHandler));
	
	TempItemName = StrReplace(Parameters.Name, "Handler", "Driver");
	
	Try
		Driver = EquipmentManagerServerCall.PredefinedItem("Catalog.HardwareDrivers." + TempItemName);
	Except
		Message = NStr("en='Predefined item %Parameter% is not found.';ru='Предопределенный элемент ""%Параметр%"" не найден.'");
		Message = StrReplace(Message, "%Parameter%", "Catalog.HardwareDrivers." + TempItemName);
		Raise Message;
	EndTry;
		
	If Driver = Undefined Then  
		Driver = Catalogs.HardwareDrivers.CreateItem();
		Driver.PredefinedDataName = TempItemName;     
		Driver.EquipmentType           = Parameters.EquipmentType;
		Driver.DriverHandler        = DriverHandler;
	Else 
		Driver = Driver.GetObject();
	EndIf;
	
	Driver.Description              = Parameters.Description;
	Driver.ObjectID      = ObjectID;
	Driver.DriverTemplateName         = DriverTemplateName; 
	Driver.SuppliedAsDistribution = SuppliedAsDistribution;
	Driver.DriverVersion            = DriverVersion;
	Driver.Write();
	
EndProcedure

#EndIf

#EndRegion