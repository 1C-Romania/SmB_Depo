////////////////////////////////////////////////////////////////////////////////
// Subsystem "Additional reports and Data processors in
// service model" safe mode extension, service procedures and functions
// 
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
// SERVICE PROGRAMMING INTERFACE

// Only for internal use.
Procedure GetPermissionsExtensionSafeModeSession(Val SessionKey, PermissionDescriptions, StandardProcessing) Export
	
	If CommonUseReUse.DataSeparationEnabled() Then
		
		StandardProcessing = False;
		
		SetPrivilegedMode(True);
		UsingDataProcessor = Catalogs.AdditionalReportsAndDataProcessors.GetRef(SessionKey);
		If AdditionalReportsAndDataProcessorsSaaS.IsSuppliedDataProcessor(UsingDataProcessor) Then
			
			SuppliedDataProcessor = AdditionalReportsAndDataProcessorsSaaS.SuppliedDataProcessor(UsingDataProcessor);
			
			QueryText =
				"SELECT
				|	permissions.TypePermissions AS TypePermissions,
				|	permissions.Parameters AS Parameters
				|FROM
				|	Catalog.SuppliedAdditionalReportsAndDataProcessors.permissions AS permissions
				|WHERE
				|	permissions.Ref = &Ref";
			Query = New Query(QueryText);
			Query.SetParameter("Ref", SuppliedDataProcessor);
			PermissionDescriptions = Query.Execute().Unload();
			
		Else
			
			Raise StringFunctionsClientServer.PlaceParametersIntoString(
				NStr("en='Supplied processing for the launch key %1 has not been found!';ru='Не обнаружена поставляемая обработка для ключа запуска %1!'"),
				String(SessionKey));
			
		EndIf;
		
	EndIf;
	
EndProcedure
