#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventsHandlers

Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	If Not AdditionalProperties.Property("SkipMainFillingCheck") Then
	
		If Not OrderNumberIsUnique(FillOrder, Ref) Then
			ErrorText = NStr("en = 'The filling sequence is not unique - there is already a volume with the same sequence'");
			CommonUseClientServer.MessageToUser(ErrorText, , "FillOrder", "Object", Cancel);
		EndIf;
		
		If MaximumSize <> 0 Then
			CurrentSizeInBytes = 0;
			If Not Ref.IsEmpty() Then
				
				FileFunctionsService.OnDefenitionSizeOfFilesOnVolume(
					Ref, CurrentSizeInBytes);
			EndIf;
			CurrentSize = CurrentSizeInBytes / (1024 * 1024);
			
			If MaximumSize < CurrentSize Then
				ErrorText = NStr("en = 'The maximum size of the volume is less than the current size'");
				CommonUseClientServer.MessageToUser(ErrorText, , "MaximumSize", "Object", Cancel);
			EndIf;
		EndIf;
		
		If IsBlankString(FullPathWindows) AND IsBlankString(FullPathLinux) Then
			ErrorText = NStr("en = 'The full path is not filled'");
			CommonUseClientServer.MessageToUser(ErrorText, , "FullPathWindows", "Object", Cancel);
			CommonUseClientServer.MessageToUser(ErrorText, , "FullPathLinux",   "Object", Cancel);
			Return;
		EndIf;
		
		If Not GetFunctionalOption("SecurityProfilesAreUsed")
		   AND Not IsBlankString(FullPathWindows)
		   AND (    Left(FullPathWindows, 2) <> "\\"
		      OR Find(FullPathWindows, ":") <> 0 ) Then
			
			ErrorText = NStr("en = 'Path to the volume must be in the UNC format (\\servername\resource).'");
			CommonUseClientServer.MessageToUser(ErrorText, , "FullPathWindows", "Object", Cancel);
			Return;
		EndIf;
	EndIf;
	
	If Not AdditionalProperties.Property("SkipAccessCheckToFolder") Then
		FullPathFieldName = "";
		FullPathOfVolume = "";
		
		ServerPlatformType = CommonUseReUse.ServerPlatformType();
		
		If ServerPlatformType = PlatformType.Windows_x86
		 OR ServerPlatformType = PlatformType.Windows_x86_64 Then
			
			FullPathOfVolume = FullPathWindows;
			FullPathFieldName = "FullPathWindows";
		Else
			FullPathOfVolume = FullPathLinux;
			FullPathFieldName = "FullPathLinux";
		EndIf;
		
		TestDirectoryName = FullPathOfVolume + "CheckAccess\";
		
		Try
			CreateDirectory(TestDirectoryName);
			DeleteFiles(TestDirectoryName);
		Except
			ErrorInfo = ErrorInfo();
			
			If GetFunctionalOption("SecurityProfilesAreUsed") Then
				ErrorTemplate =
					NStr("en = 'Path to volume is not correct.
					           |Perhaps permissions in the security
					           |profiles are not set, or account from which
					           |server 1C:Enterprise works,  hasn't access rights to the volume directory.
					           |
					           |%1'");
			Else
				ErrorTemplate =
					NStr("en = 'Path to volume is not correct.
					           |Perhaps the account from which
					           |server 1C:Enterprise works, hasn't access rights to the volume directory.
					           |
					           |%1'");
			EndIf;
			
			ErrorText = StringFunctionsClientServer.PlaceParametersIntoString(
				ErrorTemplate, BriefErrorDescription(ErrorInfo));
			
			CommonUseClientServer.MessageToUser(
				ErrorText, , FullPathFieldName, "Object", Cancel);
		EndTry;
	EndIf;
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

// Returns False if there is volume with such order.
Function OrderNumberIsUnique(FillOrder, VolumeRef)
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	COUNT(volume.FillOrder) AS Quantity
	|FROM
	|	Catalog.FileStorageVolumes AS volume
	|WHERE
	|	volume.FillOrder = &FillOrder
	|	AND volume.Ref <> &VolumeRef";
	
	Query.Parameters.Insert("FillOrder", FillOrder);
	Query.Parameters.Insert("VolumeRef", VolumeRef);
	
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		Return Selection.Quantity = 0;
	EndIf;
	
	Return True;
	
EndFunction

#EndRegion

#EndIf