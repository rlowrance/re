# e.makefile
# rerun, as necessary, all experiments e*.R

output = ../data/v6/output

# define split files
split = $(output)/transactions-subset1

apn                        = $(split)-apn.rsave
avg.commute.time           = $(split)-avg.commute.time.rsave
bathrooms                  = $(split)-bathrooms.rsave
bedrooms                   = $(split)-bedrooms.rsave
factor.is.new.construction = $(split)-factor.is.new.construction.rsave
factor.has.pool            = $(split)-factor.has.pool.rsave
fraction.improvement.value = $(split)-fraction.improvement.value.rsave
fraction.owner.occupied    = $(split)-fraction.owner.occupied.rsave
improvement.value          = $(split)-improvement.value.rsave
land.square.footage        = $(split)-land.square.footage.rsave
land.value                 = $(split)-land.value.rsave
living.area                = $(split)-living.area.rsave
log.price                  = $(split)-log.price.rsave
median.household.income    = $(split)-median.household.income.rsave
parking.spaces             = $(split)-parking.spaces.rsave
price                      = $(split)-price.rsave
recording.date             = $(split)-recordingDate.rsave
sale.date                  = $(split)-saleDate.rsave
year.built                 = $(split)-year.built.rsave

#$(warning apn is $(apn))
#$(warning avg.commute.time is $(avg.commute.time))

e_avm_variants_splits = \
  $(apn) \
  $(avg.commute.time) \
  $(bathrooms) \
  $(bedrooms) \
  $(factor.is.new.construction) \
  $(factor.has.pool) \
  $(fraction.improvement.value) \
  $(improvement.value) \
  $(land.square.footage) \
  $(land.value) \
  $(living.area) \
  $(log.price) \
  $(median.household.income) \
  $(parking.spaces) \
  $(price) \
  $(recording.date) \
  $(sale.date) \
  $(year.built)

#e_avm_variants_splits = $(apn) $(avg.commute.time)

#$(warning e_avm_variants_splits is $(e_avm_variants_splits))

targets = $(output)/e-avm-variants.rsave \
		  $(output)/e-avm-variants-synthetic-data.rsave

$(warning targets is $(targets))


.PHONY: all
all: $(targets)

$(output)/e-avm-variants.rsave: e-avm-variants.R $(e_avm_variants_splits)
	Rscript e-avm-variants.R

$(output)/e-avm-variants-synthetic-data.rsave: \
	e-avm-variants-synthetic-data.R \
	EAvmVariantsSyntheticDataReport.R
	Rscript e-avm-variants-synthetic-data.R
