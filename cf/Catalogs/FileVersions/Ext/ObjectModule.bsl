#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventsHandlers

Procedure BeforeWrite(Cancel)
	
	If DataExchange.Load Then 
		Return;
	EndIf;
	
	If AdditionalProperties.Property("FileConversion") Then
		Return;
	EndIf;
	
	If AdditionalProperties.Property("FilePlacementInVolumes") Then
		Return;
	EndIf;
	
	If IsNew() Then
		ParentalVersion = Owner.CurrentVersion;
	EndIf;
	
	If Not IsNew() Then
		
		DeletionMarkIsMarked = DeletionMark AND Not DeletionMarkInIB();
		
		DigitallySignedObjectRecord = False;
		If AdditionalProperties.Property("DigitallySignedObjectRecord") Then
			DigitallySignedObjectRecord = AdditionalProperties.DigitallySignedObjectRecord;
		EndIf;
		
		// Allow to mark the signed version for deletion.
		If Not PrivilegedMode() AND DigitallySignedObjectRecord <> True AND Not DeletionMarkIsMarked Then
			
			If ValueIsFilled(Ref) Then
				
				AttributesStructure = CommonUse.ObjectAttributesValues(Ref, "DigitallySigned, Encrypted");
				RefDigitallySigned = AttributesStructure.DigitallySigned;
				RefEncrypted = AttributesStructure.Encrypted;
				
				If DigitallySigned AND RefDigitallySigned Then
					Raise NStr("en='Cannot edit the digitally signed version.';ru='Подписанную версию нельзя редактировать.'");
				EndIf;
				
				If Encrypted AND RefEncrypted AND DigitallySigned AND Not RefDigitallySigned Then
					Raise NStr("en='Encrypted file cannot be signed.';ru='Зашифрованный файл нельзя подписывать.'");
				EndIf;
				
			EndIf;
		
		EndIf;
	EndIf;
	
	// Set the icon index when writing the object.
	PictureIndex = FileFunctionsServiceClientServer.GetFileIconIndex(Extension);
	
	If TextExtractionStatus.IsEmpty() Then
		TextExtractionStatus = Enums.FileTextExtractionStatuses.NotExtracted;
	EndIf;
	
	If TypeOf(Owner) = Type("CatalogRef.Files") Then
		Description = TrimAll(FullDescr);
	EndIf;
	
	If Owner.CurrentVersion = Ref Then
		If DeletionMark = True AND Owner.DeletionMark <> True Then
			Raise NStr("en='Active version cannot be deleted.';ru='Активную версию нельзя удалить.'");
		EndIf;
	ElsIf ParentalVersion.IsEmpty() Then
		If DeletionMark = True AND Owner.DeletionMark <> True Then
			Raise NStr("en='The first version cannot be deleted.';ru='Первую версию нельзя удалить.'");
		EndIf;
	ElsIf DeletionMark = True AND Owner.DeletionMark <> True Then
		// Clear the reference to parent one for subordinate and marked versions - 
		// change the parent version to the deleted version.
		Query = New Query;
		Query.Text = 
			"SELECT
			|	FileVersions.Ref AS Ref
			|FROM
			|	Catalog.FileVersions AS FileVersions
			|WHERE
			|	FileVersions.ParentalVersion = &ParentalVersion";
		
		Query.SetParameter("ParentalVersion", Ref);
		
		Result = Query.Execute();
		
		If Not Result.IsEmpty() Then
			Selection = Result.Select();
			Selection.Next();
			
			Object = Selection.Ref.GetObject();
			LockDataForEdit(Object.Ref);
			Object.ParentalVersion = ParentalVersion;
			Object.Write();
		EndIf;
	EndIf;
	
EndProcedure

Procedure BeforeDelete(Cancel)
	
	If FileStorageType = Enums.FileStorageTypes.InVolumesOnDrive Then
		If Not Volume.IsEmpty() Then
			FullPath = FileFunctionsService.FullPathOfVolume(Volume) + PathToFile; 
			Try
				File = New File(FullPath);
				File.SetReadOnly(False);
				DeleteFiles(FullPath);
				
				PathWithSubdirectory = File.Path;
				FileArrayInDirectory = FindFiles(PathWithSubdirectory, "*.*");
				If FileArrayInDirectory.Count() = 0 Then
					DeleteFiles(PathWithSubdirectory);
				EndIf;
				
			Except
				// Exception processing is not required.
			EndTry;
		EndIf;
	EndIf;
	
	// Check DataExchange.Load should be started from this string.
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

// Returns the current value of the deletion mark in infobase.
Function DeletionMarkInIB()
	
	Query = New Query;
	Query.Text = 
		"SELECT
		|	FileVersions.DeletionMark
		|FROM
		|	Catalog.FileVersions AS FileVersions
		|WHERE
		|	FileVersions.Ref = &Ref";
	
	Query.SetParameter("Ref", Ref);
	
	Result = Query.Execute();
	
	If Not Result.IsEmpty() Then
		Selection = Result.Select();
		Selection.Next();
		Return Selection.DeletionMark;
	EndIf;
	
	Return Undefined;
	
EndFunction

#EndRegion

#EndIf