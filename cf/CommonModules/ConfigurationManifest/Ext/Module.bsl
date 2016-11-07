#Region ApplicationInterface

// Generates configuration manifest (used to declare information
// about configuration to other service components).
//
// Returns - XDTOObject {http://www.1c.ru/1cFresh/Application/Manifest/a.b.c.d}ApplicationInfo.
//
Function GenerateConfigurationManifest() Export
	
	Manifest = XDTOFactory.Create(TypeConfigurationManifest());
	
	Manifest.Name = Metadata.Name;
	Manifest.Presentation = Metadata.Synonym;
	Manifest.Version = Metadata.Version;
	Manifest.PlatformVersion = CommonUse.GeneralBasicFunctionalityParameters().MinimallyRequiredPlatformVersion;
	
	// EVENT HANDLERS
	ApplicationEventsHandlers = CommonUseSTL.GetProgrammaticSSLEventHandlers(
		"ServiceTechnology.BasicFunctionality\WhenGeneratingConfigurationManifest");
	For Each ApplicationEventsHandler IN ApplicationEventsHandlers Do
		
		AdvancedInformation = New Array();
		
		ApplicationEventsHandler.Module.WhenGeneratingConfigurationManifest(AdvancedInformation);
		
		For Each InformationItem IN AdvancedInformation Do
			Manifest.ExtendedInfo.Add(InformationItem);
		EndDo;
		
	EndDo;
	
	Return Manifest;
	
EndFunction

// Generates configuration manifest, writes it to a file and puts the binary data of a file to the temporary storage.
// Wrapper above ConfigurationManifest.GenerateConfigurationManifest()
//  to call from the long actions or the external connection.
//
// Parameters:
//  StorageAddress - String, address in the temporary storage according to
//  which the binary data of configuration manifest is required to be placed.
//
Procedure PutConfigurationManifestToTemporaryStorage(Val StorageAddress) Export
	
	Manifest = GenerateConfigurationManifest();
	
	TempFile = GetTempFileName("xml");
	
	WriteStream = New XMLWriter();
	WriteStream.OpenFile(TempFile);
	WriteStream.WriteXMLDeclaration();
	XDTOFactory.WriteXML(WriteStream, Manifest, , , , XMLTypeAssignment.Explicit);
	WriteStream.Close();
	
	PutToTempStorage(New BinaryData(TempFile), StorageAddress);
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

Function TypeConfigurationManifest(Val Package = Undefined)
	
	Return CreateXDTOType(Package, "ApplicationInfo");
	
EndFunction

Function ConfigurationManifestPack()
	
	Return "http://www.1c.ru/1cFresh/Application/Manifest/" + ConfigurationManifestVersion();
	
EndFunction

Function ConfigurationManifestVersion()
	
	Return "1.0.0.1";
	
EndFunction

Function CreateXDTOType(Val UsingPackage, Val Type)
		
	If UsingPackage = Undefined Then
		UsingPackage = ConfigurationManifestPack();
	EndIf;
	
	Return XDTOFactory.Type(UsingPackage, Type);
	
EndFunction

#EndRegion
