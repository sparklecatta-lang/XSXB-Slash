// XSXB-Slash trail for Unreal 5 (recipe v1, docs/SPEC.md). One ProceduralMesh ribbon per recipe layer.
// Build.cs: add "ProceduralMeshComponent", "Json" to PublicDependencyModuleNames (and the plugin ProceduralMeshComponent).
// Attach this component to the weapon mesh; set HiltSocket / TipSocket (socket or bone names on that mesh),
// RecipeFile (absolute or project-relative path to recipe.json), the three textures, and the two parent materials
// built from XsxbSlashLayer.hlsl (one Translucent, one Additive).
#pragma once
#include "CoreMinimal.h"
#include "Components/SceneComponent.h"
#include "XsxbSlashTrailComponent.generated.h"

class UProceduralMeshComponent;
class UMaterialInterface;
class UMaterialInstanceDynamic;
class UTexture;

UCLASS(ClassGroup=(Effects), meta=(BlueprintSpawnableComponent))
class UXsxbSlashTrailComponent : public USceneComponent
{
	GENERATED_BODY()
public:
	UXsxbSlashTrailComponent();

	UPROPERTY(EditAnywhere, Category="XsxbSlashTrail") FString RecipeFile;
	UPROPERTY(EditAnywhere, Category="XsxbSlashTrail") FName HiltSocket;
	UPROPERTY(EditAnywhere, Category="XsxbSlashTrail") FName TipSocket;
	UPROPERTY(EditAnywhere, Category="XsxbSlashTrail") TObjectPtr<UTexture> ShapeTex;
	UPROPERTY(EditAnywhere, Category="XsxbSlashTrail") TObjectPtr<UTexture> MaskTex;
	UPROPERTY(EditAnywhere, Category="XsxbSlashTrail") TObjectPtr<UTexture> HighlightTex;
	UPROPERTY(EditAnywhere, Category="XsxbSlashTrail") TObjectPtr<UTexture> WhiteTex;   // optional, for shapeTexture "white"
	UPROPERTY(EditAnywhere, Category="XsxbSlashTrail") TObjectPtr<UMaterialInterface> AlphaMaterial;
	UPROPERTY(EditAnywhere, Category="XsxbSlashTrail") TObjectPtr<UMaterialInterface> AdditiveMaterial;
	/** Tip speed in m/s above which the blade counts as swinging. */
	/** Multiplies every layer width (recipe assumes a ~1 m blade). */
	UPROPERTY(EditAnywhere, Category="XsxbSlashTrail") float WidthScale = 1.f;
	/** Stretch shape/highlight textures over the whole visible trail (U = age / oldest age of the stroke). Off = U is plain age. */
	UPROPERTY(EditAnywhere, Category="XsxbSlashTrail") bool bFillTexture = true;
	/** Off = no new trail (existing trail fades out). Drive it from attack windows / anim notifies for clean combos. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="XsxbSlashTrail") bool bEmitting = true;
	UPROPERTY(EditAnywhere, Category="XsxbSlashTrail") float MinTipSpeed = 2.f;
	UPROPERTY(EditAnywhere, Category="XsxbSlashTrail", meta=(ClampMin=1, ClampMax=16)) int32 Substeps = 6;   // samples per frame along a Catmull-Rom curve
	/** 0 off, 1 UV0 (red age, green V), 2 frac(dist). */
	UPROPERTY(EditAnywhere, Category="XsxbSlashTrail", meta=(ClampMin=0, ClampMax=2)) int32 DebugMode = 0;

	virtual void BeginPlay() override;
	virtual void TickComponent(float DeltaTime, ELevelTick TickType, FActorComponentTickFunction* ThisTickFunction) override;

private:
	struct FSample { FVector Tip; FVector Dir; double T; float Dist; int32 Swing; };
	struct FRun
	{
		float WidthM = .8f, LifeS = .4f, Taper = .55f;
		TObjectPtr<UProceduralMeshComponent> Mesh;
		TObjectPtr<UMaterialInstanceDynamic> Mat;
	};
	TArray<FRun> Runs;
	UPROPERTY() TArray<TObjectPtr<UObject>> Keep;   // keeps meshes / MIDs alive
	struct FKey { FVector Tip; FVector Hilt; double T; };
	TArray<FSample> Samples;   // shared by all layers; each layer draws the part younger than its life
	TArray<FKey> Keys;         // last frame poses of the current swing (Catmull-Rom control points)
	FKey PrevKey{};
	int32 ProvStart = -1;      // samples from here on belong to the newest segment and are redrawn next frame
	float ProvDist = 0.f, MaxLife = 0.f;
	bool bHasPrev = false, bWas = false;
	float Dist = 0.f;   // metres
	int32 Swing = 0;
	double Now = 0.0;

	void AddSample(const FVector& Tip, const FVector& Hilt, double T);
	void Segment(const FKey& A, const FKey& B, const FKey* Before, const FKey* After);
	void Build(FRun& R);
};
