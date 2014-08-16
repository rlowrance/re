# e.makefile
# rerun, as necessary, all experiments e*.R

output = ../data/v6/output/

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
land.square.footage        = $(split)-land.square.footgage.rsave
land.value                 = $(split)-land.value.rsave
living.area                = $(split)-living.area.rsave
log.price                  = $(split)-log.price.rsave
median.household.income    = $(split)-median.household.income.rsave
parking.spaces             = $(split)-parking.spaces.rsave
price                      = $(split)-price.rsave
recording.date             = $(split)-recordingDate.rsave
sale.date                  = $(split)-saleDate.rsave
year.built                 = $(year_built)-year.built.rsave

# DETERMINE RULES FOR $(NAME); when can I write $NAME
e-avm-variants = \
  $(apn) \
  $(avg_commute_time) \
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



$(warning e_avm_variantsis $(e_avm_variants))

targets = $(output)/e-avm-variants.rsave

# pattern rule
# $< is the name of the source file  (on the RHS)
# $@ is the name of the target file (on the LHS)
%.rsave : %.R
	Rscript $<

.PHONY: all
all: $(targets)

$(output)/e-avm-variants.rsave: \
	e-avm-variants.R \
	$(e_avm_variants_splits)
