
////////////////////////////////////////////////////////////////////////////////
// EVENT HANDLERS

Procedure FormGetProcessing(FormKind, Parameters, SelectedForm, AdditionalInformation, StandardProcessing)
	
	Filter = "";
	If Parameters.Property("Filter", Filter)
		AND TypeOf(Filter) = Type("Structure") AND Filter.Count() <> 0 Then
		StandardProcessing = False;
		SelectedForm = "EDKindsByCertificate";
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// SERVICE PROCEDURES AND FUNCTIONS

#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

// For internal use only
Procedure SaveSignedEDKinds(CertificatRef, SignedED = Undefined) Export
	
	If SignedED = Undefined Then
		SignedED = New ValueTable;
		SignedED.Columns.Add("DSCertificate");
		SignedED.Columns.Add("EDKind");
		SignedED.Columns.Add("Use");
		EDKinds = ElectronicDocumentsReUse.GetEDActualKinds();
		For Each EDKind IN EDKinds Do
			NewRecord = SignedED.Add();
			NewRecord.DSCertificate = CertificatRef;
			NewRecord.EDKind = EDKind;
			NewRecord.Use = True;
		EndDo
	EndIf;

	Block = New DataLock;
	LockItem = Block.Add("InformationRegister.SignedEDKinds");
	LockItem.Mode = DataLockMode.Exclusive;
	
	BeginTransaction();
	Try
		RecordSet = InformationRegisters.DigitallySignedEDKinds.CreateRecordSet();
		RecordSet.Filter.DSCertificate.Set(CertificatRef);
		RecordSet.Load(SignedED);
		RecordSet.Write();
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

#EndIf