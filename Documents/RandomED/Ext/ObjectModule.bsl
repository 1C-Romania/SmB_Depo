Procedure Filling(FillingData, StandardProcessing)
	
	If TypeOf(FillingData) = Type("DocumentRef.RandomED") Then
		Counterparty         = FillingData.Counterparty;
		Company              = FillingData.Company;
		DocumentType         = FillingData.DocumentType;
		ConfirmationRequired = FillingData.ConfirmationRequired;
		Direction            = Enums.EDDirections.Outgoing;
		BasisDocument        = FillingData.Ref;
	EndIf;
	
EndProcedure
